# Player Movement Scripts

This folder owns click-to-move motion for the player `CharacterBody3D`.

Files:

- `player_movement_motor.gd`: destination tracking, acceleration, deceleration,
  arrival detection, and responsive direction changes.

Related scripts:

- `scripts/player/input/player_input.gd`
- `scripts/player/controllers/player_controller.gd`

GDScript notes:

- `CharacterBody3D.velocity` is the movement vector Godot uses for
  `move_and_slide()`.
- `Vector3.ZERO` means no direction.
- Horizontal movement ignores `y` so the top-down/isometric prototype stays on
  the ground plane.

Do not read mouse or keyboard input here. This motor should stay reusable for
AI, networking tests, or server-authoritative movement later.
