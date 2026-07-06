# Ground Piece Scenes

Reusable ground-piece prefabs live here.

- `GroundPieceVar1.tscn`: wrapper prefab for
  `assets/models/environment/Ground_pieces/Ground_piece_var_1.glb`.

Drop these under a level content node such as `World/LevelContent/GroundDress`
or `World/LevelContent/Roads`.

Ground-piece prefabs use `VisualMeshCollisionShape3D` so their collider is
rebuilt from the imported mesh shape instead of using a simple box.
