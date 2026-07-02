# Interaction Scripts

Shared interaction logic lives here. These scripts help different world objects
be hoverable, selectable, and visually clear to the player.

Folders:

- `hover/`: cursor hover detection and optional outline feedback.
- `selection/`: selectable target state and selected-ring feedback.

GDScript notes:

- Many interaction scripts use `NodePath` exports to point at nearby nodes in a
  scene.
- Relationship colors come from methods such as `get_relationship_color()`.

Use this folder for interaction behavior that can be reused by players, NPCs,
targets, gathering nodes, and future objects.
