# Player Feedback Scripts

Player feedback scripts spawn short visual responses to player actions.

Files:

- `player_click_feedback.gd`: spawns the yellow ground indicator when a new
  click-to-move command starts.

Related effect:

- `scenes/effects/ClickMoveIndicator.tscn`

GDScript notes:

- A `PackedScene` export lets the Inspector assign which effect scene to spawn.
- Instanced effects are added to the current scene tree, then manage their own
  animation and cleanup.

Use this folder for feedback caused by player actions, not for general effects.
