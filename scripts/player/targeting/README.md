# Player Targeting Scripts

This folder owns local target selection for the player.

Files:

- `player_targeting.gd`: raycasts under the mouse, selects `Selectable3D`
  objects, clears previous selection, and emits target changes.

Related scripts:

- `scripts/interaction/selection/selectable_3d.gd`
- `scripts/player/controllers/player_controller.gd`

GDScript notes:

- `PhysicsRayQueryParameters3D.create(...)` builds a raycast query.
- `collision_mask` controls which physics layers can be selected.
- `set_current_target(null)` clears selection.

Targeting should not decide what a click means after selection. The player
controller asks combat or gathering modules whether they can use the target.
