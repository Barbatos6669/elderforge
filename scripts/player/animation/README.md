# Player Animation Scripts

This folder controls animations on the player model.

Files:

- `player_animation_controller.gd`: loads animation clips, switches idle/jog,
  plays attack/death animations, chooses context-specific gathering loops, and
  controls playback speeds.
- `equipment_animation_profile.gd`: data resource used by tools and weapons to
  override action animations without editing player controller code.

Related scene:

- `scenes/player/Player.tscn`, child node `Animation`

GDScript notes:

- Exported animation names are strings that must match names inside the imported
  animation scene.
- The controller receives simple state calls like `set_moving(true)` instead of
  reading movement input directly.
- `play_attack()` is called by the player controller when auto-attack lands.
- `play_death()` is called by mob AI when a humanoid enemy is defeated, then
  `reset_animation_state()` returns it to idle on respawn.
- `set_gathering(true, context)` is called while a gathering channel is active.
  The context tells the controller which resource/tool family is involved.
- Equipped item definitions can provide `equipment_animation_profile_path` later
  if we bring back project-owned tool/weapon animation profiles.
- The controller currently falls back to shared animation libraries on the
  player, which keeps the project free of separate tool-specific animation
  exports.

Current sources:

- Idle, jog, punch, and `Death01` come from Universal Animation Library 1.
- Gathering placeholders use shared clips from Universal Animation Library 2.

Change this folder when the player needs different animation names, blending, or
new animation states.
