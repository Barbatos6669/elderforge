# Cursor Assets

Small cursor textures live here. Keep cursor PNGs transparent and sized close to
their intended in-game display size so Godot does not need to scale them much.

Files:

- `gather_tool_cursor.png`: resource-hover cursor used by gatherable nodes.
  It was generated from the supplied gathering-tool reference prompt, then chroma-keyed
  and resized to 48x48 for runtime use.
- `depleted_resource_cursor.png`: red X cursor used when a resource is hovered
  but cannot currently be gathered, such as a depleted tree.
- `attack_cursor.png`: hostile-target cursor used when a selectable is
  attackable.

Tune the click position on the consuming hover node with
`hover_cursor_hotspot`, `hostile_hover_cursor_hotspot`, or
`unavailable_hover_cursor_hotspot`.
