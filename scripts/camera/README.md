# Camera Scripts

Camera behavior lives here. The current game uses a perspective isometric camera
that follows the player and supports scroll-wheel zoom.

Files:

- `isometric_camera_rig.gd`: camera follow, zoom distance, and framing logic.

Related scene:

- `scenes/camera/IsometricCameraRig.tscn`

GDScript notes:

- Camera tuning values are marked with `@export`, so they can be edited in the
  Godot Inspector.
- The player controller calls `camera_rig.set_target(camera_target)` when the
  player enters the scene.

Change this folder when the camera should move, zoom, or frame the player
differently.
