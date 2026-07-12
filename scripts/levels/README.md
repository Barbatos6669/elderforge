# Level Scripts

Scripts here belong to reusable level shells, not one specific map.

- `playable_level_shell.gd`: attached to `scenes/levels/PlayableLevelShell.tscn`.
  It removes client-only UI nodes during dedicated server startup before those
  UI panels run `_ready()`. This keeps the headless server focused on world and
  network state. Client-only panels include HUD, inventory, chat, loot,
  refining, service NPC dialogue, and the master menu.
- `day_night_cycle_3d.gd`: visual-only world clock for playable levels. It
  drives the shared sun, moon, sky, ambient light, fog, and warm spawn light.

GDScript notes:

- `_enter_tree()` runs before child `_ready()` callbacks, so it is the right
  place to remove nodes that should never initialize on the server.
- `NodePath("PlayerStatusHud")` points to a child node by name. If shell UI node
  names change, update the exported array on the shell scene.
- The day/night cycle uses exported `NodePath` values to find the lights and
  `WorldEnvironment`. If you move the lighting rig in the scene tree, update
  those paths on the `DayNightCycle` node.
