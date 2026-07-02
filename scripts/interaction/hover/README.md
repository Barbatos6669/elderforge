# Hover Interaction Scripts

Hover scripts decide when the mouse is over a 3D object and apply hover feedback.

Files:

- `hover_feedback_3d.gd`: screen-bounds hover detection, optional raycast
  fallback, optional feet ring, and mesh overlay highlighting.

GDScript notes:

- `_process(delta)` checks hover every rendered frame.
- `@export_flags_3d_physics` exposes a physics collision mask in the Inspector.
- `material_overlay` is used to apply the outline material while hovered.

If hover activates too early or too late, tune the exported screen padding,
body-line radius, ray mask, or target hitbox before rewriting the script.
