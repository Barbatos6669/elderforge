# Stylized Nature MegaKit

Imported from:

```text
C:\Users\Larry\Downloads\Stylized Nature MegaKit[Standard].zip
```

This is the Quaternius Stylized Nature MegaKit Standard FREE pack.

License:

- CC0 1.0 Universal / Public Domain Dedication.
- Original license text is preserved in `License_Standard.txt`.
- Models by Quaternius.

Imported content:

- `FBX/`: 68 regular FBX files from the original pack. This folder contains
  `.gdignore` so Godot does not import the raw vendor files directly.
- `source/`: 68 editable Blender files generated from the raw FBX files.
- `models/`: 68 runtime glTF models plus their `.bin` mesh data. Godot should
  use these files when placing nature props.
- `textures/`: shared diffuse, color-mask, and normal textures used by the FBX
  meshes and glTF exports.

Skipped archive content:

- `FBX (Unity)/`: duplicate Unity-oriented FBX files.
- `OBJ/`: duplicate OBJ/MTL files.

Runtime format:

- The runtime exports use `.gltf` instead of `.glb` so all 68 assets can share
  the same texture files. A GLB export would embed duplicate copies of the same
  large bark and leaf textures into every model.

Workflow:

1. Open a file from `source/` in Blender.
2. Edit the model.
3. Export that asset back to `models/`:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_stylized_nature_megakit.py -- --asset common_tree_1
```

To regenerate all source and runtime models from the raw FBX files:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_stylized_nature_megakit.py -- --force
```

When we decide which trees, rocks, and foliage belong in the playable world,
create wrapper scenes under `scenes/props/` or `scenes/world/` so gameplay
scenes do not depend on raw pack file paths forever.
