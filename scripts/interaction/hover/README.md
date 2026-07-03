# Hover Interaction Scripts

Hover scripts decide when the mouse is over a 3D object and apply hover feedback.

Files:

- `hover_feedback_3d.gd`: screen-bounds hover detection, optional raycast
  fallback, optional feet ring, optional cursor override, and mesh overlay
  highlighting.

GDScript notes:

- `_process(delta)` checks hover every rendered frame.
- `@export_flags_3d_physics` exposes a physics collision mask in the Inspector.
- `hover_cursor_texture` points at an optional texture to use while the object
  is hovered. `hover_cursor_hotspot` controls which pixel counts as the click
  point.
- `hostile_hover_cursor_texture` is used when the hovered target implements
  `is_hostile()` and returns true. Prototype hostile targets use the attack
  cursor this way.
- `unavailable_hover_cursor_texture` is used instead when the hovered object is
  unavailable, such as a depleted gatherable resource.
- `material_overlay` is used to apply the outline material while hovered.

If hover activates too early or too late, tune the exported screen padding,
body-line radius, ray mask, or target hitbox before rewriting the script.

Gatherable resources currently use `assets/ui/cursors/gather_tool_cursor.png`
as their hover cursor and `assets/ui/cursors/depleted_resource_cursor.png` when
they are depleted.

Hostile target dummies use `assets/ui/cursors/attack_cursor.png` as their
attackable hover cursor.
