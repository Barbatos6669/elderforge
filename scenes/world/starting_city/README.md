# Starting City Scene

`StartingCity.tscn` is the current playtest entry scene. It inherits from
`res://scenes/levels/PlayableLevelShell.tscn`, so the player, UI, ground, grid,
lighting, inventory, and respawn wiring are already set up.

## Scene Layout

- `World` contains gameplay-space nodes inherited from the shell.
- `World/LevelContent` is the blank city-building area. Add city pieces under
  `GroundDress`, `Roads`, `Walls`, `Gates`, `Buildings`, `Stations`,
  `Resources`, `Mobs`, `Props`, `Lighting`, or `Navigation`.
- The scene overrides only `PlayerSpawn.spawn_id` for now.

## Editing Workflow

Open `StartingCity.tscn` and build under `World/LevelContent`. The city is
centered around `(0, 0, 0)`, so keep the spawn marker and player near origin
while blocking out the first layout.

When you add real buildings, start visual-only unless the object must block
movement. Collision and navmesh work should be added intentionally so
click-to-move stays predictable.
