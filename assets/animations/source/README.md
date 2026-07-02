# Animation Source Files

This folder stores editable source files for animation packs. It is marked with
`.gdignore` so Godot does not try to import these Blender files during normal
project loads.

Runtime animation assets live one level up in:

- `assets/animations/universal_animation_library_1/`
- `assets/animations/universal_animation_library_2/`

## Universal Animation Library 1 Source

Folder: `universal_animation_library_1/`

Extracted from:

```text
C:\Users\Larry\Downloads\Universal Animation Library[Source].zip
```

Kept files:

- `UAL1.blend`
- `README.txt`
- `License.txt`
- `root_motion_toggle.py`
- `Blender_Export_Settings.png`
- `Godot_Setup.png`

Skipped files:

- Unity `.fbx` exports.
- Redundant Unreal/Godot `.glb` exports already represented by the runtime
  imported files.

## Universal Animation Library 2 Source

Folder: `universal_animation_library_2/`

Extracted from:

```text
C:\Users\Larry\Downloads\Universal Animation Library 2[Source].zip
```

Kept files:

- `UAL2.blend`
- `README.txt`
- `License.txt`
- `root_motion_toggle.py`
- `Blender_Export_Settings.png`
- `Godot_Setup.png`
- `Female Mannequin/Mannequin_F.blend`
- `Female Mannequin/README.txt`

Skipped files:

- Unity `.fbx` exports.
- Redundant Unreal/Godot `.glb` exports already represented by the runtime
  imported files.

## Why Keep Source

The runtime player currently uses `Farm_Harvest` from Universal Animation
Library 2 for T1 hand-gathering. These source files let us later adjust that
clip in Blender so the character looks like they are ripping branches from a
basic tree instead of using a tool.
