# Texture Painting Starter Kit

This folder holds source textures and brush stamps for Blender texture painting. It is marked with `.gdignore` so Godot does not import these files as runtime game assets.

Use these files as art-source material when painting Elderforge meshes:

- `materials/`: 1K diffuse reference textures. Use these for color sampling, paint-over reference, or temporary material previews.
- `stamps/`: 1K roughness and height maps. Use these as Blender brush textures, stencil masks, crack masks, bark grain, cloth weave, dirt breakup, and surface-wear stamps.
- `polyhaven_manifest.json`: machine-readable source list for every downloaded file.
- `SOURCES.md`: human-readable source and license summary.

## Blender Use

In Blender, open Texture Paint mode and load a stamp image into the brush texture slot. For controlled placement, use stencil mapping; for softer repeated breakup, use view-plane mapping with low strength.

Suggested use:

- Bark: use `bark_wood/*height_stamp*` to stamp grooves and ridges.
- Stone: use `stone_rock/*height_stamp*` for cracks and chipped silhouettes.
- Terrain: use `terrain_ground/*roughness_stamp*` for noisy dirt/grass breakup.
- Leather and cloth: use `leather_cloth/*roughness_stamp*` for fine grain and weave.

Keep painted output files in the model's own source folder once a mesh is finalized. This folder is the shared paint toolbox, not the final game texture folder.

