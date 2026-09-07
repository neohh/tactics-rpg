# Пошаговый бой (Turn-Based Tactics RPG) — Project Guide

## Overview
Godot 4.7 turn-based tactical RPG with 3D exploration, global map, and grid-based combat. Uses Forward Plus renderer, Jolt Physics.

## Architecture

### Scenes (`.tscn`)
| Scene | Purpose |
|-------|---------|
| `menu.tscn` | Main menu (entry point) |
| `overworld3d.tscn` | Global map — travel between locations, NPC interaction |
| `explore3d.tscn` | Free movement in a location — walk with squad, pick up loot, trigger combat |
| `world3d.tscn` | Grid-based tactical combat |
| `constructor.tscn` | Level/location editor |
| `work3d.tscn` | Work scene (testing) |

### Autoloads (singletons)
| Name | Script | Purpose |
|------|--------|---------|
| `Game` | `scripts/game.gd` | Global state: party, inventory, gold, quests, flags, save/load |
| `ConHotkey` | `scripts/con_hotkey.gd` | Hotkey controller |
| `DumpTool` | `scripts/dump_tool.gd` | Debug dump utility |

### Game Flow
```
Menu → Overworld (global map) → click location → Explore3D (free walk) → proximity to enemy → World3D (combat) → victory → back to Explore or Overworld
```

1. **Overworld** (`overworld3d.gd`): Click locations to travel. If type != "town", enters explore3d. 35% random encounter chance when traveling (creates `Game.enc`, spawns encounter enemies in explore3d).
2. **Explore** (`explore3d.gd`): Free WASD movement with squad. NPCs clickable (talk/shop). Walk near enemies → auto-combat triggers.
3. **Combat** (`world3d.gd`): Grid-based tactics. Deploy or snap-from-explore. Turn-based with 2 activations/turn. Right-click rotate, middle-click pan, scroll zoom.

### Key Scripts
| Script | Purpose |
|--------|---------|
| `scripts/game.gd` | Global state, save/load, inventory, quests, party management |
| `scripts/explore3d.gd` | Free movement mode, party follow, NPC interaction, loot pickup |
| `scripts/overworld3d.gd` | Global map, travel, location click, world editor (edit_mode) |
| `scripts/world3d.gd` | Combat: unit spawning, turns, AI, attacks, skills, fire, victory/defeat |
| `scripts/party_tools.gd` | Party management: recruit, dismiss, level up, HP calc |
| `scripts/explore_tools.gd` | Utility: `snap_to_cells()` for combat positioning |
| `scripts/stats_tools.gd` | Stat calculations, XP tables |
| `scripts/config_tools.gd` | Game config reader |
| `scripts/terrain.gd` | 3D terrain: chunks, heightmap, painting, collision |
| `scripts/dialog.gd` | Dialog system |
| `scripts/battle_coordinator.gd` | Battle logic coordinator (signal-based) |
| `scripts/battle_state_manager.gd` | Battle state machine |
| `scripts/battle_ai.gd` | Enemy AI decisions |
| `scripts/action_resolver.gd` | Attack/damage resolution |
| `scripts/unit_manager.gd` | Unit CRUD operations |
| `scripts/battle_ui.gd` | Battle UI elements |
| `scripts/camp_ui.gd` | Camp/rest UI |
| `scripts/party_ui.gd` | Party management UI |
| `scripts/shop.gd` | Shop UI |
| `scripts/tavern.gd` | Tavern UI |
| `scripts/journal.gd` | Quest journal UI |
| `scripts/constructor.gd` | Level editor logic |

## Data Files (`data/`)

### Core Data
| File | Format | Description |
|------|--------|-------------|
| `locations.json` | Dict | All locations: pos, links, terrain, map (units, objects, npcs, rocks), loot, dialogs |
| `classes.json` | Dict | Unit classes: hp, move, ar (attack range), cf/cb (front/back crit), prey (counter), img |
| `chars.json` | Dict | Characters: name, class, status, shop, dialog, img. Supports inheritance via `base` field |
| `items.json` | Dict | Items: name, price, sell, heal, food, img |
| `perks.json` | Dict | Perks: name, desc, requirements, class restriction, stat mods, grants |
| `quests.json` | Dict | Quests: stages (goto, talk, clear, talk), rewards |
| `config.json` | Dict | Game balance: party_max, act_base, defeat_mode, respawn_days, xp_base |
| `groups.json` | Dict | Group definitions |

### World Data
| File | Description |
|------|-------------|
| `world_terrain.json` | Global map heightmap + chunk data |
| `world_decor.json` | Global map decorations (trees, rocks, houses) |
| `world_lights.json` | Global map light sources |
| `world_sun.json` | Sun/ambient settings |
| `materials.json` | Terrain material definitions (color, texture) |
| `loc_types.json` | Location type templates (field, town, camp, cave) |
| `loc_catalog.json` | Location catalog |

### Dialogs
- `data/dialogs/*.json` — Dialog tree files, referenced by `dlg` fields in chars/locations

## Party System
- Party stored in `Game.party` (array of dicts)
- Each member: `{char, cls, level, xp, perk_points, perks, equip, hp, maxhp}`
- Max size: `party_max` (default 6)
- Auto-filled on first entry via `PartyTools.fill_party()` with 6 predefined heroes
- `Game.party_pool` stores dismissed members

## Combat System
- Grid-based, turn-based with 2 activations per turn per unit
- 5 classes: swordsman, archer, halberd, mage, assassin
- Zone-based damage: front/side/back affects hit chance
- Skills: shove (swordsman), fire arrow (archer), sneak (assassin), heal/fire (mage), reactive halberd
- QTE system for attacks (SPACE bar timing)
- Fire terrain: mage creates burning 3x3 areas

## Location Structure
```json
{
  "name": "Location Name",
  "type": "field|town|camp|cave",
  "pos": [x, y],           // global map position
  "links": ["other_loc"],   // connected locations
  "terrain": { ... },       // local terrain heightmap
  "map": {
    "units": [...],          // combat units (team 0=player, 1=enemy, 2=neutral)
    "objects": [...],        // obstacles {cell, k}
    "npcs": [...],           // NPCs {cell, char}
    "rocks": [[x,y], ...],  // rock positions
    "elev": {...},           // elevation overrides
    "decor": "...",          // decor scene path
    "lights": [...]          // light sources
  },
  "loot": [{item, chance}],
  "dlg": {pre, win, loss, arrive, peace}
}
```

## Save System
- Auto-save to `user://save.json` (if `autosave: true` in config)
- Saves: inventory, gold, food, day, hour, fatigue, quests, flags, party, loc_state
- `Game.loc_state` per-location state: cleared_day, ground items

## Key Variables
| Variable | Location | Purpose |
|----------|----------|---------|
| `Game.explore_return` | Game | `{loc, party_pos: [[char, x, y]...]}` — return positions after combat |
| `Game.explore_start` | Game | Combat snap data from explore3d |
| `Game.enc` | Game | Random encounter data (units, objects) |
| `Game.explore_ground` | Game | Loot to place on ground when returning from combat |
| `Game.cur_loc` | Game | Current location ID |
| `Game.flags` | Game | Quest/story flags |

## Controls

### Explore Mode (explore3d)
- WASD: move squad
- Right-click drag: rotate camera (yaw + pitch)
- Middle-click drag: pan camera
- Scroll: zoom
- E: pick up loot
- R: camp/rest
- P: party management
- M: global map
- Left-click: set movement target

### Combat (world3d)
- Click unit to select
- Green cells: movement, Red cells: attack
- Q/E: rotate facing
- Right-click drag: rotate camera
- Middle-click drag: pan camera
- Scroll: zoom
- M: leave battle

### Overworld (overworld3d)
- Click location: travel or enter
- Right-click drag: rotate camera
- Middle-click drag: pan camera
- Scroll: zoom

## Editor
- `Game.edit_world = true` enables world editor mode in overworld3d
- Tools: select [1], point [2], decor [3], sculpt [T], paint [P], light [L], chunks [4]
- Location constructor: `data/loc_catalog.json`

## Addons
- `addons/loc_bridge/` — Location bridge plugin
