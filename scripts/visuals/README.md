# Shared Visual Scripts

This folder is reserved for visual helpers that are not player-only and not tied
to one UI screen.

Current state:

- `atmospheric_mist_3d.gd` gently drifts transparent mist patches used by level
  atmosphere scenes.
- `ambient_particles_3d.gd` creates lightweight ambient particle layers for
  level mood, currently moon motes and tiny leaf flecks.
- `alpha_cutout_material_3d.gd` fixes imported foliage/cards whose PNG has an
  alpha channel but whose GLB material imported as opaque.
- `occludable_visual_3d.gd` fades tagged meshes when they visually block the
  player, such as tree leaves or future building roofs.
- `tier_tinted_model_3d.gd` can be reused later if we bring back project-owned
  meshes that need tier colors.
- `toon_texture_style_3d.gd` applies the prototype toon/nearest-filter material
  style to future textured props without throwing away their texture atlases.
- `wind_sway_3d.gd` adds a small visual-only sway to tree or foliage models
  while leaving gameplay colliders fixed.
- Player-specific visual scripts currently live in `scripts/player/visuals/`.
- Hover and selection visuals live in `scripts/interaction/`.

Use this folder later for shared material helpers, mesh styling utilities,
outline helpers, or visual rules used by multiple gameplay systems.

GDScript note:

- Empty folders are easy to miss, so this README exists to explain the intended
  boundary before the folder gains code.
