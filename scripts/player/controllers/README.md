# Player Controller Scripts

The controller is the traffic director for the player prefab.

Files:

- `player_controller.gd`: coordinates input, targeting, movement, facing,
  animation, audio, combat, gathering, refining-station clicks, channeling, and
  camera.

Related scene:

- `scenes/player/Player.tscn`

GDScript notes:

- `@onready var input_reader = $Input` caches a child node from the player scene.
- `_physics_process(delta)` is used because movement and combat timing should
  advance on the physics tick.
- The controller should call methods on modules, not copy their logic.
- Refining station clicks are a small exception for now: the controller stores
  one pending station, asks it for `get_interaction_destination(...)`, and opens
  it once `can_interact_from(...)` returns true. Pull this into a shared module
  when we have more building types.

Before adding code here, ask: "Is this coordination, or does it belong in a
specific module?" If it is real work, make or update a module.
