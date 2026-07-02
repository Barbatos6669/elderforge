# Player Input Scripts

This folder reads local keyboard and mouse intent. It should not move the player
directly.

Files:

- `player_input.gd`: reads click-to-move, hold-to-move, right-click movement,
  `S` stop, and Space auto-attack input.

Related scripts:

- `scripts/player/movement/player_movement_motor.gd`
- `scripts/player/controllers/player_controller.gd`

GDScript notes:

- `Input.is_mouse_button_pressed(...)` and `Input.is_key_pressed(...)` query
  current input state.
- `_was_left_mouse_down` style variables detect "just pressed" transitions.
- Mouse clicks are converted into world positions with camera raycasts.

If a click should select, gather, or attack instead of move, another module can
consume it and call `block_click_move_until_mouse_release()`.
