# HUD Scripts

HUD scripts render in-game overlays that are always part of normal play.

Files:

- `hud_grid_layout.gd`: shared three-by-three screen layout contract. It owns
  zone anchors, outer margins, gutters, clipping, and testable zone metadata.
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
- `weapon_ability_hud.gd`: builds eight stable bottom-center spell slots and
  binds any abilities supplied by equipped items. Q/W/E come from the main
  hand, R from chest armor, D from the helmet, and F from boots. Slots 1 and 2
  remain stable future utility placeholders. Weapon passives do not consume a
  cast key.
- `weapon_ability_slot.gd`: draw-only circular spell icon, key badge, radial
  cooldown shade, remaining-seconds label, click activation, and custom
  hover-tooltip entry point.
- `ability_tooltip_panel.gd`: reusable spell hint panel with semantic tags,
  structured effects, description, energy cost, cast time, range, and cooldown.
  `WeaponAbilityHud` anchors it from the middle-center grid cell but sizes it
  against the viewport so long spell details can wrap instead of clipping.
- `world_time_hud.gd`: compact top-right UTC world clock for shared MMO-facing
  schedules.
- `hud_profile_portrait.gd`: code-drawn placeholder portrait used by the status
  HUD until we have rendered character portraits.
- `top_right_hud_menu.gd`: retired top-right HUD button strip kept as reference
  while the fullscreen UI/navigation system is being redesigned.
- HUD scripts share common colors, layer numbers, panel styles, tab styles, and
  bar styles through `scripts/ui/elderforge_ui_style.gd`.

## Nine-Zone Contract

Persistent gameplay HUD must claim a zone through `HudGridLayout.apply_zone()`
instead of anchoring directly to the viewport:

| Zone | Current owner |
| --- | --- |
| Top-left | Player portrait, name, health, and mana |
| Top-center | Reserved for target or party information |
| Top-right | UTC world clock |
| Middle-left | Reserved for contextual notices |
| Middle-center | Death and other critical notices |
| Middle-right | Reserved for contextual notices |
| Bottom-left | Chat frame and its attached tab |
| Bottom-center | Channel bar at the top; abilities at the bottom |
| Bottom-right | Gameplay map |

The zone root clips its children. When a widget has a preferred size, it must
shrink or reflow inside that root instead of crossing into a neighboring cell.
Full-screen menus, inventory windows, loot windows, and NPC dialogs are modal
UI and intentionally sit outside this persistent-HUD grid.

Related scene:

- `scenes/ui/hud/ChannelBar.tscn`
- `scenes/ui/hud/DeathMessageHud.tscn`
- `scenes/ui/hud/HudMap.tscn`
- `scenes/ui/hud/PlayerStatusHud.tscn`
- `scenes/ui/hud/WeaponAbilityHud.tscn`
- `scenes/ui/hud/WorldTimeHud.tscn`
- `scenes/ui/hud/TopRightHudMenu.tscn` is not currently instanced in playable
  levels.

GDScript notes:

- `extends CanvasLayer` means the bar draws over the 3D world.
- `HudGridLayout.Zone.BOTTOM_RIGHT` is an enum value: a readable integer name
  used to select one of the nine cells.
- `resized.connect(...)` reruns responsive child layout when the window size
  changes; the grid root itself updates automatically through Control anchors.
- Gameplay HUD layers are instanced once by `PlayableLevelShell.tscn`, not by
  `Player.tscn`, so remote player prefabs do not create duplicate local HUDs.
- Retired HUD scripts may still contain old inspector exports while we keep
  them around as reference during the UI rewrite.
- `top_right_hud_menu.gd` uses `_configure_icon_button(...)` so new HUD buttons
  can share the same icon sizing, tooltip, focus, and style setup.
- Fullscreen submenu navigation belongs in `scripts/ui/menu/master_menu.gd`;
  HUD buttons should route to that menu instead of owning their own popups.
- Use `ElderforgeUiStyle` for repeated `StyleBoxFlat` and label styling before
  adding new local style helpers.
- Ability tooltips read `tooltip_tags` and `tooltip_effects` from the equipped
  `WeaponAbilityDefinition`; do not hard-code spell text in HUD slots.
- The script connects to channeling signals in `_connect_channeling()`.
- `ProgressBar.value` is driven from `0.0` to `1.0`.

Keep this folder about HUD display. The actual channel timing lives in
`scripts/player/channeling/player_channeling.gd`.
