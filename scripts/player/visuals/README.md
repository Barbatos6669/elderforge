# Player Visual Scripts

This folder owns player-only visual presentation.

Files:

- `player_facing.gd`: rotates the visual model toward movement, combat, or
  gathering direction.
- `player_visual_style.gd`: applies the current toon-like placeholder material
  style to the base character.

Related scene:

- `scenes/player/Player.tscn`

GDScript notes:

- Visual rotation is separate from movement so the model can face a target while
  the `CharacterBody3D` remains stable.
- Material changes affect `MeshInstance3D` children under the model root.
- `NodePath` exports point these scripts at the visual root.

Use this folder for player look and presentation, not gameplay rules.
