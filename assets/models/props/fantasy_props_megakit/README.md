# Fantasy Props MegaKit

Imported from:

```text
C:\Users\Larry\Downloads\Fantasy Props MegaKit[Standard].zip
```

This is the Quaternius Fantasy Props MegaKit Standard FREE pack.

License:

- CC0 1.0 Universal / Public Domain Dedication.
- Original license text is preserved in `License_Standard.txt`.
- Models by Quaternius.

Imported content:

- `FBX/`: 94 regular FBX files from the original pack. This folder contains
  `.gdignore` so Godot does not import the raw vendor files directly.
- `source/`: editable Blender files generated from the raw FBX files.
- `models/`: runtime glTF models plus their `.bin` mesh data. Godot should use
  these files when placing props.
- `textures/`: shared prop, furniture, cloth, metal, and page texture atlases.
- `preview/`: original preview images from the pack.

Skipped archive content:

- `Exports/glTF/`: duplicate vendor runtime exports.
- `Exports/OBJ/`: duplicate OBJ/MTL files.

Runtime format:

- The runtime exports use `.gltf` instead of `.glb` so all props can share the
  same texture files. A GLB export would embed duplicate copies of the same
  large texture atlases into every model.

Workflow:

1. Open a file from `source/` in Blender.
2. Edit the model.
3. Export that asset back to `models/`:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_fantasy_props_megakit.py -- --asset anvil
```

To regenerate all source and runtime models from the raw FBX files:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_fantasy_props_megakit.py -- --force
```

When we pick props for gameplay scenes, wrap them in scenes under
`scenes/props/` or `scenes/world/` so gameplay code does not depend on raw pack
file paths forever.
