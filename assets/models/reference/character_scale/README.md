# Character Scale Reference

Open this file in Blender when making custom props:

```text
assets/models/reference/character_scale/source/character_scale_reference.blend
```

It contains the current player character imported from:

```text
assets/characters/base/Superhero_Male_FullBody.gltf
```

The scene also includes:

- A 1-meter floor grid.
- A 1-meter cube.
- The visible character body at roughly `1.82m` tall.
- A transparent player collision capsule matching the current Godot player
  capsule: `1.8m` tall with `0.35m` radius.
- Height markers for `1m` and `1.8m`.

Blender uses `Z` as vertical. Our Godot runtime uses `Y` as vertical, and the
project's Blender export scripts handle that conversion with `export_yup=True`.

To rebuild the reference scene after the base character changes:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_character_scale_reference.py -- --force
```
