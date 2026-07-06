# Start Here

This is the short navigation page for the current prototype. Use it when the
project feels too big and you just need the next file to open.

## Run The Game

Godot currently starts here:

```text
scenes/world/starting_city/StartingCity.tscn
```

`StartingCity.tscn` inherits from:

```text
scenes/levels/PlayableLevelShell.tscn
```

The shell owns the common setup: player, UI, flat ground, debug grid, lighting,
inventory, HUD, refining UI, and loot UI. The starting city scene should hold
map-specific things you place by hand.

## Most Common Files

| Goal | Open This |
| --- | --- |
| Move the player spawn | `scenes/world/starting_city/StartingCity.tscn` |
| Change player movement/camera/combat modules | `scenes/player/Player.tscn` |
| Tune shared level setup | `scenes/levels/PlayableLevelShell.tscn` |
| Add or change prototype items | `scripts/inventory/prototype_item_catalog.gd` |
| Change inventory behavior | `scripts/inventory/player_inventory.gd` |
| Change inventory UI | `scripts/ui/inventory/inventory_panel.gd` |
| Change gathering behavior | `scripts/player/gathering/player_gathering.gd` |
| Change resource node behavior | `scripts/gathering/gatherable_resource_3d.gd` |
| Change auto attack | `scripts/player/combat/player_auto_attack.gd` |
| Change player stats | `scripts/player/stats/player_stats.gd` |

## Folder Rule Of Thumb

- `scenes/` is what you place in Godot.
- `scripts/` is behavior.
- `assets/` is art, audio, materials, item icons, Blender sources, and imported
  runtime files.
- `docs/` is learning notes and design direction.
- `tools/` is import/export/generation scripts.

## When Adding Something New

1. Add scene/prefab files near similar scene files.
2. Add reusable behavior near similar scripts.
3. Add art source files under `assets/`, keeping Blender source and exported
   runtime files together when possible.
4. Add a short README only when the folder would confuse a new contributor.

For the bigger map, use `docs/CODEBASE_INDEX.md`. For the learning walkthrough,
use `docs/CODEBASE_GUIDE.md`. For folder rules, use
`docs/PROJECT_STRUCTURE.md`.
