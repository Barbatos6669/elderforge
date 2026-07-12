# HUD Scripts

HUD scripts render in-game overlays that are always part of normal play.

Files:

- `channel_bar.gd`: listens to `PlayerChanneling` and shows action name,
  progress, and remaining time.
- `death_message_hud.gd`: listens to `PlayerRespawn` and shows a death message
  with a respawn countdown.
- `hud_map.gd`: compact bottom-right gameplay map. It samples world groups and
  service containers, then passes marker positions to `hud_map_view.gd`.
- `hud_map_view.gd`: draw-only minimap body for grid, player, resource, mob,
  and service markers.
- `player_status_hud.gd`: top-left player portrait, name, health bar, and mana
  bar.
- `world_time_hud.gd`: compact top-right UTC world clock for shared MMO-facing
  schedules.
- `hud_profile_portrait.gd`: code-drawn placeholder portrait used by the status
  HUD until we have rendered character portraits.
- `top_right_hud_menu.gd`: retired top-right HUD button strip kept as reference
  while the fullscreen UI/navigation system is being redesigned.
- HUD scripts share common colors, layer numbers, panel styles, tab styles, and
  bar styles through `scripts/ui/elderforge_ui_style.gd`.

Related scene:

- `scenes/ui/hud/ChannelBar.tscn`
- `scenes/ui/hud/DeathMessageHud.tscn`
- `scenes/ui/hud/HudMap.tscn`
- `scenes/ui/hud/PlayerStatusHud.tscn`
- `scenes/ui/hud/WorldTimeHud.tscn`
- `scenes/ui/hud/TopRightHudMenu.tscn` is not currently instanced in playable
  levels.

GDScript notes:

- `extends CanvasLayer` means the bar draws over the 3D world.
- Retired HUD scripts may still contain old inspector exports while we keep
  them around as reference during the UI rewrite.
- `top_right_hud_menu.gd` uses `_configure_icon_button(...)` so new HUD buttons
  can share the same icon sizing, tooltip, focus, and style setup.
- Fullscreen submenu navigation belongs in `scripts/ui/menu/master_menu.gd`;
  HUD buttons should route to that menu instead of owning their own popups.
- Use `ElderforgeUiStyle` for repeated `StyleBoxFlat` and label styling before
  adding new local style helpers.
- The script connects to channeling signals in `_connect_channeling()`.
- `ProgressBar.value` is driven from `0.0` to `1.0`.

Keep this folder about HUD display. The actual channel timing lives in
`scripts/player/channeling/player_channeling.gd`.
