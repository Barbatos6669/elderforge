# Axe Gathering Tool Assets

Each axe tier has its own editable source file and runtime export so the tiers
can grow into different silhouettes, textures, materials, VFX, and icons.

Folder contract per tier:

- `source/`: artist-edited Blender files.
- `models/`: exported Godot runtime GLB files.
- `textures/`: baked or hand-painted textures for this tier.
- `materials/`: tier-specific material resources or notes.
- `vfx/`: tier-specific particles, trails, glows, or impact visuals.
- `icons/`: inventory/tool icons for this tier.

Example:

```text
assets/equipment/tools/axes/t4/
  source/t4_axe.blend
  models/t4_axe.glb
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
