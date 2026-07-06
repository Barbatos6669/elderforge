# Art Tools

This folder contains small deterministic art generators for project assets that
need stable layout or metadata.

Current tool:

- `create_world_texture_atlas.py`: builds the shared world texture atlas PNG,
  labeled preview PNG, and JSON UV metadata.

Run from the project root:

```powershell
python tools/art/create_world_texture_atlas.py
```

These scripts are useful when an asset must remain predictable for code or UV
mapping. Once a placeholder becomes real art, keep the file paths and metadata
stable so scenes and materials do not need to be rewired.
