# Bootstrap Scripts

Bootstrap scripts decide which scene the game enters first.

- `sign_in_gateway.gd`: starts on the separate sign-in scene, waits for a
  successful auth event, then loads the playable world. Dedicated server runs
  skip the UI and jump straight into the game scene.

GDScript notes:

- `get_tree().change_scene_to_file(...)` replaces the current scene tree with
  another `.tscn`.
- `call_deferred(...)` waits until the current frame is safe for scene changes.
