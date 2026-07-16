# Debug Scripts

Debug scripts help us see and test the prototype. They should not become core
gameplay dependencies.

Files:

- `debug_spawn_point_3d.gd`: visible Marker3D used to mark prototype spawn
  points while still behaving like a normal spawn transform.
- `isometric_grid.gd`: draws the isometric reference grid used in the main test
  scene.
- `mob_aggro_zone_debug_3d.gd`: debug-only ground ring synced by `EnemyMobAI`
  to visualize a mob's aggro radius.

Related scene:

- `scenes/debug/DebugSpawnPoint.tscn`
- `scenes/debug/IsometricGrid.tscn`

GDScript notes:

- Debug drawing often creates meshes or lines at runtime.
- Keep debug exports easy to tune in the Inspector.

It is okay for debug helpers to be simple and disposable. Keep production
systems out of this folder.
