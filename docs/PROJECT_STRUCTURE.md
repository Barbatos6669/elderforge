# Project Structure

Use this as the quick rulebook for where files should go.

## Top Level

| Folder | What Goes Here |
| --- | --- |
| `assets/` | Character art, animation packs, audio, materials, textures, UI art, and item data. |
| `scenes/` | Godot scenes and prefabs you can instance in the editor. |
| `scripts/` | GDScript behavior attached to scenes or reusable gameplay systems. |
| `docs/` | Learning notes, roadmap, design rules, lore, and project guides. |
| `tools/` | Small automation helpers that do not depend on deleted imported model folders. |

## Current Art Rule

The project currently keeps the base character, shared animation packs, and
project-owned resource art:

```text
assets/characters/base/
assets/animations/
assets/trees/
```

World props, terrain pieces, gathering nodes, equipment, and buildings should
come from project-owned assets or Godot-native prototypes.

## Tool Layout

| Folder | Purpose |
| --- | --- |
| `tools/art/` | Small helper scripts for generated textures or images. |

## Naming Rules

- Use lowercase folder names with underscores: `player_stats`, not `PlayerStats`.
- Use descriptive scene names in PascalCase: `PlayerNameplate.tscn`.
- Avoid placeholder folders like `New Folder` or names with spaces.
- Keep future imported art in a clearly named, project-owned folder and document
  the workflow before adding broad asset packs again.
