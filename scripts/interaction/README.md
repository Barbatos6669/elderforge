# Interaction Scripts

Shared interaction logic lives here. These scripts help different world objects
be hoverable, selectable, and visually clear to the player.

Folders:

- `cursor/`: shared temporary mouse cursor overrides.
- `hover/`: cursor hover detection and optional outline feedback.
- `selection/`: selectable target state and selected-ring feedback.

GDScript notes:

- Many interaction scripts use `NodePath` exports to point at nearby nodes in a
  scene.
- Custom cursors use `Input.set_custom_mouse_cursor(...)`; keep ownership in
  `cursor_override.gd` so one hover node does not clear another node's cursor.
- Relationship colors come from methods such as `get_relationship_color()`.

Use this folder for interaction behavior that can be reused by players, NPCs,
targets, gathering nodes, and future objects.
