# Axe Gathering Tool Assets

Each axe tier has its own editable source file and runtime export so the tiers
can grow into different silhouettes, textures, materials, VFX, and icons.

Folder contract per tier:

- `source/`: artist-edited Blender files.
- `models/`: exported Godot runtime GLB files.
- `animations/`: item-specific animation profile resources.
  - `animations/source/`: editable Blender animation source files.
  - `animations/exports/`: exported Godot runtime animation GLB files.
- `textures/`: baked or hand-painted textures for this tier.
- `materials/`: tier-specific material resources or notes.
- `vfx/`: tier-specific particles, trails, glows, or impact visuals.
- `icons/`: inventory/tool icons for this tier.

Example:

```text
assets/equipment/tools/axes/t4/
  source/t4_axe.blend
  models/t4_axe.glb
  animations/t4_axe_animation_profile.tres
  animations/source/t4_axe_animations.blend
  animations/exports/t4_axe_animations.glb
  textures/
  materials/
  vfx/
  icons/
```

After editing a tier source file, export only that tier:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/equipment/tools/axes/t4/source/t4_axe.blend --python tools/blender/export_axe_tier_asset.py
```

The matching Godot scene is under `scenes/equipment/tools/axes/`, such as
`Tier4Axe.tscn`. Item definitions point at those scenes instead of directly at
the GLB files.

To edit an axe gathering animation, open that tier's editable Blender file, such
as `animations/source/t4_axe_animations.blend`, edit the action, then export it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/axes/t4/animations/source/t4_axe_animations.blend --python tools/blender/export_axe_animation_tier_asset.py
```

The matching profile, such as `animations/t4_axe_animation_profile.tres`, points
at `animations/exports/t4_axe_animations.glb` and uses the local clip
`T4_Axe_TreeChopping`.
