# Player Animation Scripts

This folder controls animations on the player model.

Files:

- `player_animation_controller.gd`: loads animation clips, switches idle/jog,
  plays attack animation, chooses context-specific gathering loops, and controls
  playback speeds.
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
- `set_gathering(true, context)` is called while a gathering channel is active.
  The context tells the controller which resource/tool family is involved.
- Equipped item definitions can provide `equipment_animation_profile_path`.
  Those profiles live in item folders, such as
  `assets/equipment/tools/axes/t4/animations/t4_axe_animation_profile.tres`.
- Animation profiles store imported clip names and can optionally point at a
  tier-local animation export, such as
  `assets/equipment/tools/axes/t4/animations/exports/t4_axe_animations.glb`.
  The controller lazy-loads the named clip from that local export first, then
  falls back to the shared gathering animation scene.

Current sources:

- Idle, jog, and punch come from Universal Animation Library 1.
- Axe gathering on logs uses tier-local clips such as `T4_Axe_TreeChopping`,
  initially generated from Universal Animation Library 2.
- Hammer, pickaxe, sickle, and skinning-knife gathering currently use the shared
  `TreeChopping` clip as a placeholder. Each tool still has its own animation
  profile, so later swaps should happen in the relevant `.tres` profile instead
  of inside controller code.

Change this folder when the player needs different animation names, blending, or
new animation states.
