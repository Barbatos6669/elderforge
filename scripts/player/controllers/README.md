# Player Controller Scripts

The controller is the traffic director for the player prefab.

Files:

- `player_controller.gd`: coordinates input, targeting, movement, facing,
  animation, audio, combat, gathering, refining-station clicks, loot-container
  clicks, channeling, combat-state activity, death/respawn locks, and camera.

Related scene:

- `scenes/player/Player.tscn`

GDScript notes:

- `@onready var input_reader = $Input` caches a child node from the player scene.
- `_physics_process(delta)` is used because movement and combat timing should
  advance on the physics tick.
- The controller should call methods on modules, not copy their logic.
- Remote multiplayer players are visual-only copies. Network packets update a
  target position/facing, and `player_controller.gd` smooths the visible copy
  toward that target each physics tick. Tune `remote_position_smoothing_hz`,
  `remote_rotation_smoothing_hz`, and `remote_snap_distance` on the Player
  scene if online movement feels too floaty or too snappy.
- Refining station and loot bag clicks are small exceptions for now: the
  controller stores one pending interactable, asks it for
  `get_interaction_destination(...)`, and opens it once
  `can_interact_from(...)` returns true. Pull this into a shared interaction
  module when the pattern grows again.

Before adding code here, ask: "Is this coordination, or does it belong in a
specific module?" If it is real work, make or update a module.
