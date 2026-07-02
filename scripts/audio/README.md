# Audio Scripts

Shared audio logic lives here. Player-specific audio goes under
`scripts/player/audio/`.

Read first:

- `../README.md` for the GDScript syntax primer.
- `footsteps/README.md` for the current surface footstep resource.

Current folders:

- `footsteps/`: reusable data resources for footstep clip sets.

Add scripts here when the audio behavior is reusable by multiple systems. If it
only belongs to the player prefab, put it in `scripts/player/audio/`.
