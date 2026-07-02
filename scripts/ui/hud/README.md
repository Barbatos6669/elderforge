# HUD Scripts

HUD scripts render in-game overlays that are always part of normal play.

Files:

- `channel_bar.gd`: listens to `PlayerChanneling` and shows action name,
  progress, and remaining time.

Related scene:

- `scenes/ui/hud/ChannelBar.tscn`

GDScript notes:

- `extends CanvasLayer` means the bar draws over the 3D world.
- The script connects to channeling signals in `_connect_channeling()`.
- `ProgressBar.value` is driven from `0.0` to `1.0`.

Keep this folder about HUD display. The actual channel timing lives in
`scripts/player/channeling/player_channeling.gd`.
