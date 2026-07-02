# Player Channeling Scripts

Channeling means "a timed action is currently filling a progress bar". Gathering
uses it now; spells, recall, mounting, and crafting can use it later.

Files:

- `player_channeling.gd`: starts, updates, completes, and cancels timed actions.

Related UI:

- `scenes/ui/hud/ChannelBar.tscn`
- `scripts/ui/hud/channel_bar.gd`

GDScript notes:

- `signal channel_started(...)`, `channel_completed(...)`, and
  `channel_cancelled(...)` are events other scripts listen to.
- `context: Dictionary` carries action-specific data without hardcoding
  gathering or spell logic into the channel module.
- `update_channel(delta)` should be called every physics frame by the player
  controller.

Keep this folder generic. Do not put tree, spell, or inventory reward logic in
the channel timer.
