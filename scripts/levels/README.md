# Level Scripts

Scripts here belong to reusable level shells, not one specific map.

- `playable_level_shell.gd`: attached to `scenes/levels/PlayableLevelShell.tscn`.
  It removes client-only UI nodes during dedicated server startup before those
  UI panels run `_ready()`. This keeps the headless server focused on world and
  network state.

GDScript notes:

- `_enter_tree()` runs before child `_ready()` callbacks, so it is the right
  place to remove nodes that should never initialize on the server.
- `NodePath("InventoryPanel")` points to a child node by name. If the shell UI
  node names change, update the exported array on the shell scene.
