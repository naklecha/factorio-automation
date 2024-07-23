# factorio-automation
<i>this repository is work in progress...</i>

```factorio-automation``` is a powerful mod that provides a set of remote interfaces that can be used to create Factorio agents. This library allows users to control player actions, manage resources, and automate complex processes through simple function calls.

<div>
    <img src="image.jpeg"/>
</div>

## Usage
To use these remote interfaces, call them using the remote.call function in Factorio:
```
remote.call("factorio_tasks", "command_name", arg1, arg2, ...)
```

## Commands

### Movement and Interaction
- `walk_to_entity(entity_type, entity_name, search_radius)`
  Walk to the nearest specified entity within range.

- `mine_entity(entity_type, entity_name)`
  Mine the nearest specified entity.

- `place_entity(entity_name)`
  Place the specified entity at current position.

### Inventory Management
- `place_item_in_chest(item_name, count)`
  Put items into a nearby chest.

- `auto_insert_nearby(item_name, entity_type, max_count)`
  Insert items into nearby entities, up to a limit.

- `pick_up_item(item_name, count, container_type)`
  Collect items from nearby containers.

### Crafting and Research
- `craft_item(item_name, count)`
  Craft a number of specified items.

- `research_technology(technology_name)`
  Start researching a technology.

### Combat
- `attack_nearest_enemy(search_radius)`
  Attack the closest enemy within range.

### Utility
- `log_player_info(player_id)`
  Record detailed player information.

## Example
This example, collects 5 stone, crafts a stone furnace, places a stone furnace, collects iron and coal and then places them in the stone furnace. 
```lua
-- Walk to stone and place furnace 
/c remote.call("factorio_tasks", "walk_to_entity", "resource", "stone", 500)

/c remote.call("factorio_tasks", "mine_entity", "resource", "stone")
/c remote.call("factorio_tasks", "mine_entity", "resource", "stone")
/c remote.call("factorio_tasks", "mine_entity", "resource", "stone")
/c remote.call("factorio_tasks", "mine_entity", "resource", "stone")
/c remote.call("factorio_tasks", "mine_entity", "resource", "stone")

/c remote.call("factorio_tasks", "craft_item", "stone-furnace", 1)
/c remote.call("factorio_tasks", "place_entity", "stone-furnace")

-- Walk to and mine coal
/c remote.call("factorio_tasks", "walk_to_entity", "resource", "coal", 500)
/c remote.call("factorio_tasks", "mine_entity", "resource", "coal")
/c remote.call("factorio_tasks", "mine_entity", "resource", "coal")
/c remote.call("factorio_tasks", "mine_entity", "resource", "coal")
/c remote.call("factorio_tasks", "mine_entity", "resource", "coal")
/c remote.call("factorio_tasks", "mine_entity", "resource", "coal")

-- Walk to and mine iron ore
/c remote.call("factorio_tasks", "walk_to_entity", "resource", "iron-ore", 500)
/c remote.call("factorio_tasks", "mine_entity", "resource", "iron-ore")
/c remote.call("factorio_tasks", "mine_entity", "resource", "iron-ore")
/c remote.call("factorio_tasks", "mine_entity", "resource", "iron-ore")
/c remote.call("factorio_tasks", "mine_entity", "resource", "iron-ore")
/c remote.call("factorio_tasks", "mine_entity", "resource", "iron-ore")

-- Walk to the nearest furnace
/c remote.call("factorio_tasks", "walk_to_entity", "furnace", "stone-furnace", 50)

-- Put coal into the furnace
/c remote.call("factorio_tasks", "auto_insert_nearby", "coal", "furnace", 5)

-- Put iron ore into the furnace
/c remote.call("factorio_tasks", "auto_insert_nearby", "iron-ore", "furnace", 5)
```

### Contributing
Contributions to Automate Factorio are welcome! Please feel free to submit pull requests, create issues or spread the word.