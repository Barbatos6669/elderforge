# Foliage Materials

Materials and shaders here are for trees, leaves, bushes, and other vegetation.

- `pixel_dissolve_toon.gdshader` is an older experimental foliage dissolve
  shader. Current player-occlusion fading uses
  `assets/materials/occlusion/pixel_occlusion_fade.gdshader` instead, because
  it does not require a de-render mesh.

Inspector notes:

- Prefer `OccludableVisual3D` for trees that should reveal the player. Tag only
  the leaf/canopy meshes, not the trunk.
