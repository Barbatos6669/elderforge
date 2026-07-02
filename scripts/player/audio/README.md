# Player Audio Scripts

This folder owns sounds that are played by the player prefab.

Files:

- `player_footstep_audio.gd`: plays footstep clips based on movement and
  animation timing.

Related data:

- `assets/audio/footsteps/sets/grass_footsteps.tres`
- `assets/audio/footsteps/sets/hard_footsteps.tres`
- `scripts/audio/footsteps/footstep_surface_set.gd`

GDScript notes:

- This script extends `AudioStreamPlayer`, so the node itself can play sound.
- `surface_set` is a `Resource` assigned in the Inspector.
- The player controller calls `set_moving(...)`; the audio script decides when
  to trigger each step.

Future terrain detection should choose which surface set is active.
