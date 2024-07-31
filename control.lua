-- Constants
local TASK_STATES = {
    IDLE = 0,
    WALKING_TO_ENTITY = 1,
    MINING = 2,
    PLACING = 3,
    PLACING_IN_CHEST = 4,
    PICKING_UP = 5,
    CRAFTING = 6,
    RESEARCHING = 7,
    WALKING_DIRECT = 8,
    AUTO_INSERTING = 9,
    ATTACKING = 10
}

-- Configuration
local CONFIG = {
    SEARCH_RADIUS = 20,
    PATH_UPDATE_INTERVAL = 60,  -- Update path every 60 ticks
    BOUNDING_BOX = {{-0.5, -0.5}, {0.5, 0.5}},
    COLLISION_MASK = {"player-layer", "train-layer", "consider-tile-transitions", "water-tile", "object-layer"}
}

-- Global Variables
local setup_complete = false
local player_state = {
    task_state = TASK_STATES.IDLE,
    parameters = {}
}

-- Utility functions
local function log_message(message)
    log("[AUTOMATE]" .. message)
end

local function get_player()
    local player = game.connected_players[1]
    if not player or not player.character then
        log_message("No valid player found")
        return nil
    end
    return player
end

local function get_direction(start_position, end_position)
    local angle = math.atan2(end_position.y - start_position.y, start_position.x - end_position.x)
    local octant = (angle + math.pi) / (2 * math.pi) * 8 + 0.5

    if octant < 1 then
        return defines.direction.east
    elseif octant < 2 then
        return defines.direction.northeast
    elseif octant < 3 then
        return defines.direction.north
    elseif octant < 4 then
        return defines.direction.northwest
    elseif octant < 5 then
        return defines.direction.west
    elseif octant < 6 then
        return defines.direction.southwest
    elseif octant < 7 then
        return defines.direction.south
    else
        return defines.direction.southeast
    end
end

local function start_mining(player, entity_position)
    player.update_selected_entity(entity_position)
    player.mining_state = {mining = true, position = entity_position}
    log_message("Started mining at position: " .. serpent.line(entity_position))
end

-- Log player info 
-- Basically, creates a huge table of info with inventory, position, research info, etc.
local function log_player_info(player_id)
    local player = get_player()

    local log_data = {}

    log_data.name = player.name
    log_data.position = player.position
    log_data.force = player.force.name

    local main_inventory = player.get_main_inventory()
    if main_inventory then
        log_data.inventory = {}
        for name, count in pairs(main_inventory.get_contents()) do
            table.insert(log_data.inventory, {name = name, count = count})
        end
    end

    if player.character and player.character.grid then
        log_data.equipment = {}
        for _, equipment in pairs(player.character.grid.equipment) do
            table.insert(log_data.equipment, {name = equipment.name, position = equipment.position})
        end
    end

    log_data.nearby_entities = {}
    local nearby_entities = player.surface.find_entities_filtered({
        position = player.position,
        radius = 20
    })
    for _, entity in pairs(nearby_entities) do
        table.insert(log_data.nearby_entities, {name = entity.name, position = entity.position})
    end

    log_data.map_info = {
        surface_name = player.surface.name,
        daytime = player.surface.daytime,
        wind_speed = player.surface.wind_speed,
        wind_orientation = player.surface.wind_orientation
    }

    log_data.research = {
        current_research = player.force.current_research and player.force.current_research.name or "None",
        research_progress = player.force.research_progress
    }

    log_data.technologies = {}
    for name, tech in pairs(player.force.technologies) do
        if tech.researched then
            table.insert(log_data.technologies, name)
        end
    end 

    log_data.crafting_queue = {}
    for i = 1, player.crafting_queue_size do
        local item = player.get_crafting_queue_item(i)
        if item then
            table.insert(log_data.crafting_queue, {name = item.recipe, count = item.count})
        end
    end

    if player.character then
        log_data.character_stats = {
            health = player.character.health,
            mining_progress = player.character.mining_progress,
            vehicle = player.vehicle and player.vehicle.name or "None"
        }
    end

    log_message("Player Info: " .. serpent.block(log_data))
end

-- Are these similar to helper functions? But as tasks?
-- I think these are the functions that are called in the Lua console? 
remote.add_interface("factorio_tasks", 
{
    -- Walk to an entity
    -- Creates the task and passes on to calculate path if needed?
    walk_to_entity = function(entity_type, entity_name, search_radius)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start walk_to_entity task: Player is not idle")
            return false
        end
        
        log_message("New walk_to_entity task: " .. entity_type .. ", " .. entity_name .. ", radius: " .. search_radius)
        player_state.task_state = TASK_STATES.WALKING_TO_ENTITY
        player_state.parameters = {
            entity_type = entity_type,
            entity_name = entity_name,
            search_radius = search_radius,
            path = nil,
            path_drawn = false,
            path_index = 1,
            calculating_path = false,
            should_mine = false,
            target_position = nil
        }
        return true
    end,
   
    -- Mine an entity
    -- Takes in an entity type and entity name 
    mine_entity = function(entity_type, entity_name)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start mine_entity task: Player is not idle")
            return false
        end
        log_message("New mine_entity task: " .. entity_type .. ", " .. entity_name)
        player_state.task_state = TASK_STATES.MINING
        player_state.parameters = {
            entity_type = entity_type,
            entity_name = entity_name
        }
    end,

    -- Place an entity
    -- Takes an entity name
    place_entity = function(entity_name)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start place_entity task: Player is not idle")
            return false
        end
        player_state.task_state = TASK_STATES.PLACING
        player_state.parameters = {
            entity_name = entity_name
        }
        log_message("New place_entity task: " .. entity_name)
        return true
    end,

    -- Place an item in chest
    -- Takes in an item name and count
    place_item_in_chest = function(item_name, count)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start place_item_in_chest task: Player is not idle")
            return false
        end
        player_state.task_state = TASK_STATES.PLACING_IN_CHEST
        player_state.parameters = {
            item_name = item_name,
            count = count or 1,
            search_radius = 8
        }
        log_message("New place_item_in_chest task: " .. item_name .. " x" .. count)
        return true
    end,

    -- Auto insert nearby
    -- Takes in an item name, the entity take and a max count
    auto_insert_nearby = function(item_name, entity_type, max_count)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start auto_insert_nearby task: Player is not idle")
            return false, "Task already in progress"
        end
        player_state.task_state = TASK_STATES.AUTO_INSERTING
        player_state.parameters = {
            item_name = item_name,
            entity_type = entity_type,
            max_count = max_count or math.huge
        }
        log_message("New auto_insert_nearby task for " .. item_name .. " into " .. entity_type)
        return true, "Task started"
    end,

    -- Pick up item 
    -- Takes in item_name, count and container_type
    pick_up_item = function(item_name, count, container_type)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start pick_up_item task: Player is not idle")
            return false, "Task already in progress"
        end
        player_state.task_state = TASK_STATES.PICKING_UP
        player_state.parameters = {
            item_name = item_name,
            count = count or 1,
            container_type = container_type,
            search_radius = 8
        }
        log_message("New pick_up_item task: " .. item_name .. " x" .. count .. " from " .. container_type)
        return true, "Task started"
    end,

    -- Craft an item
    -- Takes in an item_name and count
    craft_item = function(item_name, count)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start craft_item task: Player is not idle")
            return false, "Task already in progress"
        end
        local player = get_player()
        if not player.force.recipes[item_name] then
            log_message("Cannot start craft_item task: Recipe not available")
            return false, "Recipe not available"
        end
        if not player.force.recipes[item_name].enabled then
            log_message("Cannot start craft_item task: Recipe not unlocked")
            return false, "Recipe not unlocked"
        end
        player_state.task_state = TASK_STATES.CRAFTING
        player_state.parameters = {
            item_name = item_name,
            count = count or 1,
            crafted = 0
        }
        log_message("New craft_item task: " .. item_name .. " x" .. count)
        return true, "Task started"
    end,

    -- Attack the nearest enemy
    -- Takes in a search radius
    attack_nearest_enemy = function(search_radius)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start attack_nearest_enemy task: Player is not idle")
            return false, "Task already in progress"
        end
        player_state.task_state = TASK_STATES.ATTACKING
        player_state.parameters = {
            search_radius = search_radius or 50,
            target = nil
        }
        log_message("New attack nearest enemy task, search radius: " .. player_state.parameters.search_radius)
        return true, "Task started"
    end,

    -- Research a technolog_messagey 
    -- Takes in a technolog_messagey name
    research_technolog_messagey = function(technolog_messagey_name)
        if player_state.task_state ~= TASK_STATES.IDLE then
            log_message("Cannot start research_technolog_messagey task: Player is not idle")
            return false, "Task already in progress"
        end
        local player = get_player()
        local force = player.force
        local tech = force.technolog_messageies[technolog_messagey_name]
        
        if not tech then
            log_message("Cannot start research_technolog_messagey task: Technolog_messagey not found")
            return false, "Technolog_messagey not found"
        end
        
        if tech.researched then
            log_message("Cannot start research_technolog_messagey task: Technolog_messagey already researched")
            return false, "Technolog_messagey already researched"
        end
        
        if not tech.enabled then
            log_message("Cannot start research_technolog_messagey task: Technolog_messagey not available for research")
            return false, "Technolog_messagey not available for research"
        end
        
        if not force.research_queue_enabled and force.current_research then
            log_message("Cannot start research_technolog_messagey task: Research already in progress")
            return false, "Research already in progress"
        end
        
        force.add_research(tech)
        log_message("New research_technolog_messagey task: " .. technolog_messagey_name)
        return true, "Research started"
    end,

    log_message_player_info = function(player_id)
        log_message_player_info(player_id)
        return true
    end,
})

-- Event handlers
-- for when a path calculation is completed
script.on_event(defines.events.on_script_path_request_finished, function(event)
    if event.path and player_state.task_state == TASK_STATES.WALKING_TO_ENTITY then
        player_state.parameters.path = event.path
        player_state.parameters.path_drawn = false
        player_state.parameters.path_index = 1
        player_state.parameters.calculating_path = false
        log_message("Path calculation completed. Path length: " .. #event.path)
    else
        log_message("Path calculation failed, switching to direct walking")
        player_state.task_state = TASK_STATES.WALKING_DIRECT
        player_state.parameters.calculating_path = false
    end
end)

-- Event handler for when a player mines something
script.on_event(defines.events.on_player_mined_entity, function(event)
    log_message("Entity mined, resetting to IDLE state")
    player_state.task_state = TASK_STATES.IDLE
    player_state.parameters = {}
end)

-- Main loop event handler
script.on_event(defines.events.on_tick, function(event)
    -- Setup the game
    if not setup_complete then
        local surface = game.surfaces[1]
        local enemies = surface.find_entities_filtered{force = "enemy"}
        log_message("Removing " .. #enemies .. " enemies")
        for _, enemy in pairs(enemies) do
            enemy.destroy()
        end
        
        setup_complete = true
        log_message("Setup complete")
    end

    local player = get_player()

    -- Shrug shoulders if player is idle
    if player_state.task_state == TASK_STATES.IDLE then
        return
    end
    
    -- Handle different task states
    -- if walking
    if player_state.task_state == TASK_STATES.WALKING_TO_ENTITY then
        local nearest_entity = nil
        local min_distance = math.huge
        
        local entities = player.surface.find_entities_filtered({
            position = player.position,
            radius = player_state.parameters.search_radius,
            type = player_state.parameters.entity_type,
            name = player_state.parameters.entity_name
        })
        if(#entities == 0) then
            log_message("No entities found, reverting to IDLE state")
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
            return
        end

        -- Find the nearest entity
        for _, entity in pairs(entities) do
            local distance = (entity.position.x - player.position.x)^2 + (entity.position.y - player.position.y)^2
            if distance < min_distance then
                min_distance = distance
                nearest_entity = entity
            end
        end

        log_message("Nearest entity position: " .. serpent.line(nearest_entity.position))
        log_message("Player position: " .. serpent.line(player.position))
        log_message("Player bounding box: " .. serpent.line(player.character.bounding_box))
        
        -- Get a path to the nearest entity if we haven't already
        if nearest_entity and not player_state.parameters.calculating_path and not player_state.parameters.path then
            local character = player.character
             -- TODO: improve path following
             -- currently using larger than character bbox as a workaround for the path following getting stuck on objects
             -- may sometimes still get stuck on trees and will fail to find small passages
            local bbox = {{-0.5, -0.5}, {0.5, 0.5}}
            local start = player.surface.find_non_colliding_position(
                "iron-chest", -- TODO: using iron chest bbox so request_path doesn't fail standing near objects using the larger bbox
                character.position,
                10,
                0.5,
                false
            )
            player.surface.request_path{
                bounding_box = bbox,
                collision_mask = {
                    "player-layer",
                    "train-layer",
                    "consider-tile-transitions",
                    "water-tile",
                    "object-layer"
                },
                radius = 2,
                start = start,
                goal = nearest_entity.position,
                force = player.force,
                entity_to_ignore = character,
                pathfind_flags = {
                    cache = false,
                    no_break = true,
                    prefer_straight_paths = false,
                    allow_paths_through_own_entities = false
                }
            }
            player_state.parameters.calculating_path = true
            player_state.parameters.target_position = nearest_entity.position
            log_message("Requested path calculation to " .. serpent.line(nearest_entity.position))
        end
        
        -- If we finally have a path, follow it
        if player_state.parameters.path and nearest_entity then
            -- Draw the path
            if not player_state.parameters.path_drawn then
                for i = 1, #player_state.parameters.path - 1 do
                    rendering.draw_line{
                        color = {r = 0, g = 1, b = 0},
                        width = 2,
                        from = player_state.parameters.path[i].position,
                        to = player_state.parameters.path[i + 1].position,
                        surface = player.surface,
                        time_to_live = 600,
                        draw_on_ground = true
                    }
                end
                player_state.parameters.path_drawn = true
                log_message("Path drawn on ground")
            end

            local path = player_state.parameters.path
            local path_index = player_state.parameters.path_index
            
            -- Move the player along the path (in the direction)
            if path_index <= #path and math.sqrt((nearest_entity.position.x - player.position.x)^2+(nearest_entity.position.y - player.position.y)^2) > 1 then
                local next_position = path[path_index].position
                local direction = get_direction(player.position, next_position)
                
                player.walking_state = {
                    walking = true,
                    direction = direction
                }
                
                -- Make sure we are going to next position correctly
                if (next_position.x - player.position.x)^2 + (next_position.y - player.position.y)^2 < 0.01 then
                    player_state.parameters.path_index = path_index + 1
                    log_message("Moving to next path index: " .. player_state.parameters.path_index)
                end
                -- Make sure we reach the target
                if (nearest_entity.position.x - player.position.x)^2 + (nearest_entity.position.y - player.position.y)^2 < 2 then
                    player_state.state = TASK_STATES.IDLE
                    player_state.parameters = {}
                    log_message("Reached target entity, switching to IDLE state")
                end
            else
                -- We've reached the target - now what
                rendering.clear()
                player.walking_state = {walking = false}
                
                if player_state.parameters.should_mine then
                    log_message("Switching to MINING state")
                    player_state.task_state = TASK_STATES.MINING
                else
                    log_message("Task completed, switching to IDLE state")
                    player_state.task_state = TASK_STATES.IDLE
                    player_state.parameters = {}
                end
            end
        end

    -- Mining state
    elseif player_state.task_state == TASK_STATES.MINING then
        -- Find the nearest entity to mine
        local nearest_entity = player.surface.find_entities_filtered({
            position = player.position,
            radius = 2,
            type = player_state.parameters.entity_type,
            name = player_state.parameters.entity_name,
            limit = 1
        })[1]
        log_message("Mining entity: " .. player_state.parameters.entity_name)
        if nearest_entity then
            start_mining(player, nearest_entity.position)
        else
            log_message("No entity found to mine, switching to IDLE state")
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
        end

    -- Placing state
    elseif player_state.task_state == TASK_STATES.PLACING then
        if not player then 
            log_message("Invalid player, ending PLACING task")
            return false, "Invalid player" 
        end

        local surface = player.surface
        local inventory = player.get_main_inventory()
        
        if not inventory then 
            log_message("Cannot access player inventory, ending PLACING task")
            return false, "Cannot access player inventory" 
        end

        local item_name = game.entity_prototypes[player_state.parameters.entity_name].items_to_place_this[1]
        if not item_name then 
            log_message("Invalid entity name, ending PLACING task")
            return false, "Invalid entity name" 
        end

        local item_stack = inventory.find_item_stack(player_state.parameters.entity_name)
        if not item_stack then 
            log_message("Entity not found in inventory, ending PLACING task")
            return false, "Entity not found in inventory" 
        end

        if not player_state.parameters.position then
            position = surface.find_non_colliding_position(player_state.parameters.entity_name, player.position, 1, 1)
            if not position then 
                log_message("Could not find a valid position to place the entity, ending PLACING task")
                return false, "Could not find a valid position to place the entity" 
            end
        end

        player_state.task_state = TASK_STATES.IDLE
        local create_entity_args = {
            name = player_state.parameters.entity_name,
            position = position,
            force = player.force,
            raise_built = true,
            player = player
        }
        local entity = surface.create_entity(create_entity_args)
        
        if entity then
            item_stack.count = item_stack.count - 1
            log_message("Entity placed successfully: " .. player_state.parameters.entity_name)
            return true, "Entity placed successfully", entity
        else
            log_message("Failed to place entity: " .. player_state.parameters.entity_name)
            return false, "Failed to place entity"
        end

    -- log_messageic for automatically inserting items into nearby entities
    elseif player_state.task_state == TASK_STATES.AUTO_INSERTING then
        local player = get_player()
        local nearby_entities = player.surface.find_entities_filtered({
            position = player.position,
            radius = 8,
            type = player_state.parameters.entity_type,
            force = player.force
        })
    
        local player_inventory = player.get_main_inventory()
        local item_stack = player_inventory.find_item_stack(player_state.parameters.item_name)
        local inserted_total = 0
    
        if item_stack then
            for _, entity in pairs(nearby_entities) do
                if entity.can_insert({name = player_state.parameters.item_name}) then
                    local to_insert = math.min(item_stack.count, player_state.parameters.max_count - inserted_total)
                    local inserted = entity.insert({name = player_state.parameters.item_name, count = to_insert})
                    if inserted > 0 then
                        player_inventory.remove({name = player_state.parameters.item_name, count = inserted})
                        inserted_total = inserted_total + inserted
                        log_message("Inserted " .. inserted .. " " .. player_state.parameters.item_name .. " into " .. entity.name)
                    end
                    
                    if inserted_total >= player_state.parameters.max_count then
                        break
                    end
                end
            end
        end
    
        if inserted_total == 0 then
            log_message("No items inserted, ending task")
        else
            log_message("Inserted a total of " .. inserted_total .. " " .. player_state.parameters.item_name)
        end
        
        player_state.task_state = TASK_STATES.IDLE
        player_state.parameters = {}

    -- If player wants to pick up
    elseif player_state.task_state == TASK_STATES.PICKING_UP then
        local player = get_player()
        local nearby_containers = player.surface.find_entities_filtered({
            position = player.position,
            radius = player_state.parameters.search_radius,
            type = player_state.parameters.container_type,
            force = player.force
        })
    
        local player_inventory = player.get_main_inventory()
        local picked_up_total = 0
    
        for _, container in pairs(nearby_containers) do
            if container.get_inventory(defines.inventory.chest) then
                local container_inventory = container.get_inventory(defines.inventory.chest)
                local item_stack = container_inventory.find_item_stack(player_state.parameters.item_name)
                
                -- If stack, calculate how much you can pick up
                if item_stack then
                    local to_pick_up = math.min(item_stack.count, player_state.parameters.count - picked_up_total)
                    local picked_up = player_inventory.insert({name = player_state.parameters.item_name, count = to_pick_up})
                    
                    if picked_up > 0 then
                        container_inventory.remove({name = player_state.parameters.item_name, count = picked_up})
                        picked_up_total = picked_up_total + picked_up
                        log_message("Picked up " .. picked_up .. " " .. player_state.parameters.item_name .. " from " .. container.name)
                    end
                    
                    if picked_up_total >= player_state.parameters.count then
                        break
                    end
                end
            end
        end
    
        if picked_up_total == 0 then
            log_message("No items picked up, ending task")
        else
            log_message("Picked up a total of " .. picked_up_total .. " " .. player_state.parameters.item_name)
        end
        
        player_state.task_state = TASK_STATES.IDLE
        player_state.parameters = {}

    -- Crafting state
    elseif player_state.task_state == TASK_STATES.CRAFTING then
        local player = get_player()
        local recipe = player.force.recipes[player_state.parameters.item_name]
        
        if not recipe then
            log_message("Recipe not found, ending task")
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
            return
        end

        local ingredients = recipe.ingredients
        local player_inventory = player.get_main_inventory()
        local can_craft = true

        -- Loop through the ingredients and make sure you have everything
        for _, ingredient in pairs(ingredients) do
            if player_inventory.get_item_count(ingredient.name) < ingredient.amount then
                can_craft = false
                log_message("Not enough " .. ingredient.name .. " to craft " .. player_state.parameters.item_name)
                break
            end
        end

        if can_craft then
            -- Interesting - you remove the ingredients and add the crafted item
            for _, ingredient in pairs(ingredients) do
                player_inventory.remove({name = ingredient.name, count = ingredient.amount})
            end

            local crafted_item = recipe.result
            game.player.insert({name = crafted_item, count = 1})

            player_state.parameters.crafted = player_state.parameters.crafted + 1

            log_message("Crafted 1 " .. player_state.parameters.item_name)

            if player_state.parameters.crafted >= player_state.parameters.count then
                log_message("Crafting task complete")
                player_state.task_state = TASK_STATES.IDLE
                player_state.parameters = {}
            end
        -- If can't craft, switch to idle
        else
            log_message("Not enough ingredients to craft, ending task")
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
        end

    -- Researching state
    elseif player_state.task_state == TASK_STATES.RESEARCHING then
        local force = player.force
        local tech = force.technolog_messageies[player_state.parameters.technolog_messagey_name]

        -- With this, are you able to research while doing other things? Don't remember how that works in game
        if tech.researched then
            log_message("Research completed: " .. player_state.parameters.technolog_messagey_name)
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
        elseif force.current_research ~= tech then
            log_message("Research interrupted: " .. player_state.parameters.technolog_messagey_name)
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
        end

    -- Direct walking state
    elseif player_state.task_state == TASK_STATES.WALKING_DIRECT then
        local player = get_player()
        local target = player_state.parameters.target_position
        
        if target then
            local direction = get_direction(player.position, target)
            player.walking_state = {
                walking = true,
                direction = direction
            }
            
            if (target.x - player.position.x)^2 + (target.y - player.position.y)^2 < 2 then
                log_message("Reached target, switching to IDLE state")
                player_state.task_state = TASK_STATES.IDLE
                player_state.parameters = {}
            end
        else
            log_message("No target position, switching to IDLE state")
            player_state.task_state = TASK_STATES.IDLE
            player_state.parameters = {}
        end
    end
end)
