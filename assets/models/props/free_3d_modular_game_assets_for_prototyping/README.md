# Free 3D Modular Game Assets For Prototyping

Imported from:

```text
C:\Users\Larry\Downloads\Free 3D Modular Game Assets For Prototyping.zip
```

This pack was created by Raphael Goncalves / Rgsdev.

License:

- CC0 / public domain.
- Original license text is preserved in `License.txt`.
- Credit is not required by the license.

Imported content:

- `FBX/`: 81 raw FBX files from the original pack. This folder contains
  `.gdignore` so Godot does not import the vendor files directly.
- `source/`: editable Blender files generated from the raw FBX files.
- `models/`: runtime glTF models plus their `.bin` mesh data.
- `textures/`: shared `texture.png` from the pack.

Runtime format:

- The runtime exports use `.gltf` instead of `.glb` so the modular pieces can
  share the same texture file.

Workflow:

1. Open a file from `source/` in Blender.
2. Edit the model.
3. Export that asset back to `models/`:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_modular_prototyping_assets.py -- --asset wall
```

To regenerate all source and runtime models from the raw FBX files:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_modular_prototyping_assets.py -- --force
```

Godot wrapper prefabs live under:

```text
scenes/props/free_3d_modular_game_assets_for_prototyping/
```
