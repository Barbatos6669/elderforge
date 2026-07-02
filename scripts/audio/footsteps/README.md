# Footstep Audio Scripts

This folder defines reusable footstep data. The player script that plays those
sounds is in `scripts/player/audio/player_footstep_audio.gd`.

Files:

- `footstep_surface_set.gd`: a `Resource` that stores a named set of footstep
  clips for one surface type, such as grass or hard ground.

GDScript notes:

- `extends Resource` means this script is data, not a scene-tree node.
- `@export var clips: Array[AudioStream]` exposes a list in the Inspector.
- The `.tres` files in `assets/audio/footsteps/sets/` are saved instances of
  this resource.

Use this folder when adding new reusable footstep data types.
