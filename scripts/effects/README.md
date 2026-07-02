# Effects Scripts

Small visual effects live here. These scripts should be reusable and should
usually free themselves when the effect is over.

Files:

- `click_move_indicator.gd`: double-ring click marker that grows and fades on
  the ground.

Related scene:

- `scenes/effects/ClickMoveIndicator.tscn`

GDScript notes:

- Tweens animate values over time without writing manual frame logic.
- `queue_free()` removes the effect node after it finishes.

Use this folder for one-off visual effects, not for long-lived UI or character
logic.
