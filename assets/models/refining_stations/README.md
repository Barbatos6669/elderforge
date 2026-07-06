# Refining And Crafting Station Models

This folder contains editable Blender source for station models we expect to
redesign later: sawmills, stonecutters, smelters, looms, tool makers, and weapon
smiths.

Folder contract per family and tier:

- `source/`: artist-edited Blender files. Each source folder has `.gdignore`
  so Godot does not try to import Blender source files directly.
- `models/`: exported runtime GLB files.
- `textures/`: baked or hand-painted textures.
- `materials/`: station-specific material resources or notes.
- `vfx/`: smoke, sparks, cloth motion, saw effects, and other visuals.
- `icons/`: station/building icons when needed.

Example:

```text
assets/models/refining_stations/sawmills/t4/
  source/t4_sawmill.blend
  models/t4_sawmill.glb
  textures/
  materials/
  vfx/
  icons/
```

After editing one source file, export that tier:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/refining_stations/sawmills/t4/source/t4_sawmill.blend --python tools/blender/export_refining_station_tier_asset.py
```

`tools/blender/create_refining_station_tier_assets.py` regenerates the current
scripted placeholders. Use it only when you intentionally want to rebuild the
placeholder sources from code.
