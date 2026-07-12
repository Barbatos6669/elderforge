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
- `material_color_override_3d.gd` recolors selected imported material surfaces
  by material name, such as turning only a bush's flower material white while
  preserving its alpha mask.
- `character_appearance_assets.gd` is the shared catalog for Universal Base
  Character body, hair, and outfit paths. Add new compatible character assets
  here first so gameplay and UI previews stay in sync.
- `character_rig_attachment.gd` moves rigged hair/outfit mesh instances from an
  imported GLTF scene onto the live character skeleton so one animation rig can
  drive every visible character piece.
- `character_toon_materials.gd` builds the shared character/toon materials used
  by player bodies, hair, outfits, and character preview screens.
- `occludable_visual_3d.gd` fades tagged meshes when they visually block the
  player, such as tree leaves or future building roofs.
- `tier_tinted_model_3d.gd` can be reused later if we bring back project-owned
  meshes that need tier colors.
- `toon_texture_style_3d.gd` applies the prototype toon/nearest-filter material
  style to future textured props without throwing away their texture atlases.
- `scene_toon_material_pass.gd` is a runtime-only whole-scene test pass for the
  experimental toon shader. It preserves simple albedo colors/textures and skips
  common transparent/effect nodes so we can compare the overall art direction.
- `wind_sway_3d.gd` adds a small visual-only sway to tree or foliage models
  while leaving gameplay colliders fixed.
- Player-specific visual scripts currently live in `scripts/player/visuals/`.
- Hover and selection visuals live in `scripts/interaction/`.

Put reusable visual rules here when more than one gameplay/UI system needs
them. Keep prefab-specific tuning near the prefab that owns it.

GDScript note:

- `class_name SomeName` registers a script as a project-wide type, so another
  script can call `SomeName.some_static_function()` without manually loading the
  file.
- `static func` means the function belongs to the class itself, not to a node
  instance in the scene tree.
- `NodePath("Armature/Skeleton3D")` is a saved path through the scene tree. If
  imported character packages rename their skeleton path, update the shared
  constant in `character_appearance_assets.gd`.
