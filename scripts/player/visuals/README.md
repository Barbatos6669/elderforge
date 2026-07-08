# Player Visual Scripts

This folder owns player-only visual presentation.

Files:

- `player_facing.gd`: rotates the visual model toward movement, combat, or
  gathering direction.
- `player_occlusion_silhouette.gd`: shows a depth-disabled filled character
  silhouette with an outline when buildings, trunks, walls, or registered
  visual occluders such as fading leaves block the camera.
- `player_visual_style.gd`: optional prototype material override used by NPCs or
  test characters. The local player currently preserves `BaseCharacter.glb`'s
  imported material.

Related scene:

- `scenes/player/Player.tscn`

GDScript notes:

- Visual rotation is separate from movement so the model can face a target while
  the `CharacterBody3D` remains stable.
- Material changes affect `MeshInstance3D` children under the model root.
- `NodePath` exports point these scripts at the visual root.

Use this folder for player look and presentation, not gameplay rules.
