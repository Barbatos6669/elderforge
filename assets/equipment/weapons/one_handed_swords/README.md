# One-Handed Sword Equipment

This folder is the art-facing home for one-handed sword assets.

Folder contract per tier:

- `source/`: artist-edited Blender files. Each source folder has `.gdignore`
  so Godot does not try to import Blender source files directly.
- `models/`: exported Godot runtime GLB files.
- `textures/`: baked or hand-painted textures.
- `materials/`: tier-specific material resources or notes.
- `vfx/`: tier-specific particles, trails, glows, or impact visuals.
- `icons/`: inventory/weapon icons for this tier.

Current setup:

- `t1/source/t1_one_handed_sword.blend` through
  `t8/source/t8_one_handed_sword.blend` are editable Blender source files.
- `t1/models/t1_one_handed_sword.glb` through
  `t8/models/t8_one_handed_sword.glb` are runtime exports.
- `Tier1OneHandedSword.tscn` through `Tier8OneHandedSword.tscn` point at those
  GLB exports.
- `assets/models/equipment/attachments/one_handed_sword_main_hand.tres`
  controls the hand offset.

After editing one tier source file, export that tier:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/weapons/one_handed_swords/t4/source/t4_one_handed_sword.blend --python tools/blender/export_one_handed_sword_tier_asset.py
```

Use `tools/blender/create_one_handed_sword_tier_assets.py` only when you want to
regenerate the scripted placeholder from scratch. Normal art edits should happen
directly in Blender.
