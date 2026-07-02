# Cursor Interaction Scripts

Cursor helpers live here. They keep temporary cursor changes from fighting each
other when different hover or UI systems are active.

Files:

- `cursor_override.gd`: static helper used by hover nodes to request and release
  a custom mouse cursor.

GDScript notes:

- `static func` means callers do not need to place a node in the scene tree.
- `Input.set_custom_mouse_cursor(texture, shape, hotspot)` replaces a Godot
  cursor shape until the texture is cleared.
- The `owner` argument is the node that requested the cursor. Only that same
  owner can release the active override.
