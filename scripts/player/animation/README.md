# Player Animation Scripts

This folder controls animations on the player model.

Files:

- `player_animation_controller.gd`: loads animation clips, switches idle/jog,
  plays attack animation, and controls movement animation speed.

Related scene:

- `scenes/player/Player.tscn`, child node `Animation`

GDScript notes:

- Exported animation names are strings that must match names inside the imported
  animation scene.
- The controller receives simple state calls like `set_moving(true)` instead of
  reading movement input directly.
- `play_attack()` is called by the player controller when auto-attack lands.

Change this folder when the player needs different animation names, blending, or
new animation states.
