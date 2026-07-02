# Player Animation Scripts

This folder controls animations on the player model.

Files:

- `player_animation_controller.gd`: loads animation clips, switches idle/jog,
  plays attack animation, loops gathering animation, and controls playback
  speeds.

Related scene:

- `scenes/player/Player.tscn`, child node `Animation`

GDScript notes:

- Exported animation names are strings that must match names inside the imported
  animation scene.
- The controller receives simple state calls like `set_moving(true)` instead of
  reading movement input directly.
- `play_attack()` is called by the player controller when auto-attack lands.
- `set_gathering(true)` is called while a gathering channel is active.

Current sources:

- Idle, jog, and punch come from Universal Animation Library 1.
- T1 tree gathering uses `Farm_Harvest` from Universal Animation Library 2 so
  the character looks like they are pulling or harvesting by hand instead of
  swinging an axe.

Change this folder when the player needs different animation names, blending, or
new animation states.
