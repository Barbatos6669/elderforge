# Playable Level Shell

`PlayableLevelShell.tscn` is the reusable setup scene for any level that should
run immediately in play mode.

## What It Provides

- `World`, `Ground`, `DebugGrid`, `PlayerSpawn`, and `Player`
- player respawn wiring back to `PlayerSpawn`
- basic lighting and environment
- `World/LevelContent/Lighting/BasicLevelLighting`
- `PlayerInventory`
- inventory, player HUD, death message, refining, and loot UI wiring
- `World/LevelContent` folders for level-specific content

## New Level Workflow

1. Create a new inherited scene from `PlayableLevelShell.tscn`.
2. Rename the root to the level name, such as `StartingCity`.
3. Add level art and gameplay objects under `World/LevelContent`.
4. Override `PlayerSpawn.spawn_id` if the level needs a unique spawn name.
5. Set `project.godot`'s main scene to the new level while it is the active
   playtest map.

Keep common player/UI setup in this shell. Keep map-specific objects in each
level scene.

The default lighting rig lives at
`res://scenes/levels/lighting/BasicLevelLighting.tscn`. Tune that prefab when
all playable levels need a better shared look, or instance a different lighting
prefab under a level's `World/LevelContent/Lighting` folder for map-specific
lighting.
