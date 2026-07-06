# Project Structure

Use this as the quick rulebook for where files should go.

## Top Level

| Folder | What Goes Here |
| --- | --- |
| `assets/` | Art, audio, materials, item data, textures, Blender source, and runtime model exports. |
| `scenes/` | Godot scenes and prefabs you can instance in the editor. |
| `scripts/` | GDScript behavior attached to scenes or reusable gameplay systems. |
| `docs/` | Learning notes, roadmap, design rules, and project guides. |
| `tools/` | Automation scripts for Blender, Godot scene generation, and art helpers. |

## Custom Prop Layout

Custom props made for Elderforge live here:

```text
assets/models/props/barbatos_props/
```

Each prop should use this layout:

```text
prop_name/
  source/      editable Blender files
  models/      exported .glb or .gltf files used by Godot
  textures/    texture atlases and prop-specific images
```

Matching prefab scenes go here:

```text
scenes/props/barbatos_props/
```

Regenerate those wrapper scenes with:

```powershell
python tools/godot/generate_barbatos_prop_prefabs.py
```

## Tool Layout

| Folder | Purpose |
| --- | --- |
| `tools/blender/` | Scripts that open Blender or export Blender-authored assets. |
| `tools/godot/` | Scripts that generate Godot scenes/resources from existing assets. |
| `tools/art/` | Small helper scripts for generated textures or images. |

## Naming Rules

- Use lowercase folder names with underscores: `table_v1`, not `Tablev1`.
- Use `source/`, `models/`, and `textures/` for art assets that will be edited
  and exported later.
- Use descriptive scene names in PascalCase: `TableV1.tscn`,
  `RetainingWall1.tscn`.
- Avoid placeholder folders like `New Folder` or names with spaces.
