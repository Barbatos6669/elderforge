# World Materials

Shared world-space materials live here.

- `world_texture_atlas_material.tres`: starter material for the world texture
  atlas.
- `stylized_water.tres`: reusable animated water surface material using
  scrolling normal maps, depth fade, Fresnel, and foam.
- `stylized_water.gdshader`: shader used by water plane prefabs.

Water notes:

- The water shader is visual only. It does not add collision or gameplay water
  behavior.
- Color, alpha, depth fade, normal strength, wave speed, wave height, foam, and
  Fresnel can be tuned from the material resource in the Godot Inspector.
- Water normals, foam, and wave phase use world-space coordinates, so scaling
  the water plane should not stretch the texture. Tune `texture_tile_size` when
  the ripple scale needs to look larger or smaller.
- Foam is intentionally an overlay, not the base color. If the surface reads too
  pale, lower `foam_amount` or `foam_opacity` first.
- The current water plane uses mesh subdivisions so the small vertex wave has
  geometry to move.
