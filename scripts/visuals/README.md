# Shared Visual Scripts

This folder is reserved for visual helpers that are not player-only and not tied
to one UI screen.

Current state:

- `tier_tinted_model_3d.gd` can be attached to a shared imported model instance
  when the same mesh needs different tier colors.
- `toon_texture_style_3d.gd` applies the prototype toon/nearest-filter material
  style to imported textured props without throwing away their texture atlases.
- `wind_sway_3d.gd` adds a small visual-only sway to tree or foliage models
  while leaving gameplay colliders fixed.
- Player-specific visual scripts currently live in `scripts/player/visuals/`.
- Hover and selection visuals live in `scripts/interaction/`.

Use this folder later for shared material helpers, mesh styling utilities,
outline helpers, or visual rules used by multiple gameplay systems.

GDScript note:

- Empty folders are easy to miss, so this README exists to explain the intended
  boundary before the folder gains code.
