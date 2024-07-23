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

## Examples
```lua
-- Walk to an iron ore patch
remote.call("factorio_tasks", "walk_to_entity", "resource", "iron-ore", 50)

-- Mine copper ore
remote.call("factorio_tasks", "mine_entity", "resource", "copper-ore")

-- Place an assembling machine
remote.call("factorio_tasks", "place_entity", "assembling-machine-1")

-- Craft electronic circuits
remote.call("factorio_tasks", "craft_item", "electronic-circuit", 50)

-- Research automation technology
remote.call("factorio_tasks", "research_technology", "automation")
```

### Contributing
Contributions to Automate Factorio are welcome! Please feel free to submit pull requests, create issues or spread the word.