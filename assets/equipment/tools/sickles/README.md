# Sickle Gathering Tool Assets

Each sickle tier has its own editable source file and runtime export so fiber
gathering tools can grow into different silhouettes, textures, materials, VFX,
and icons.

Folder contract per tier:

- `source/`: artist-edited Blender files.
- `models/`: exported Godot runtime GLB files.
- `animations/`: item-specific animation profile resources.
- `textures/`: baked or hand-painted textures for this tier.
- `materials/`: tier-specific material resources or notes.
- `vfx/`: tier-specific particles, trails, glows, or harvesting visuals.
- `icons/`: inventory/tool icons for this tier.

Example:

```text
assets/equipment/tools/sickles/t4/
  source/t4_sickle.blend
  models/t4_sickle.glb
  animations/t4_sickle_animation_profile.tres
  textures/
  materials/
  vfx/
  icons/
```

After editing a tier source file, export only that tier:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/sickles/t4/source/t4_sickle.blend --python tools/blender/export_sickle_tier_asset.py
```

The matching Godot scene is under `scenes/equipment/tools/sickles/`, such as
`Tier4Sickle.tscn`. Item definitions point at those scenes instead of directly
at the GLB files.

To change which character animation a tier uses, open that tier's
`animations/t#_sickle_animation_profile.tres` in Godot and edit the clip names.

Each `source/` folder has a `.gdignore` file because Godot runtime scenes use
the exported GLB, while the `.blend` files are artist source files edited in
Blender 5.1.
