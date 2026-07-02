# Debug Scripts

Debug scripts help us see and test the prototype. They should not become core
gameplay dependencies.

Files:

- `isometric_grid.gd`: draws the isometric reference grid used in the main test
  scene.

Related scene:

- `scenes/debug/IsometricGrid.tscn`

GDScript notes:

- Debug drawing often creates meshes or lines at runtime.
- Keep debug exports easy to tune in the Inspector.

It is okay for debug helpers to be simple and disposable. Keep production
systems out of this folder.
