# Barbatos Props

Custom props made for Elderforge live here.

Suggested folder layout for each prop:

```text
prop_name/
  source/      editable Blender files
  models/      runtime `.glb` or `.gltf` exports
  textures/    texture atlases and prop-specific textures
```

`source/` is for files you edit in Blender. Runtime models should be exported to
`models/` so Godot scenes can reference a stable path. Put textures beside the
prop in `textures/` instead of leaving them loose in the root folder.

To generate wrapper prefabs for every `.glb` or `.gltf` in this folder:

```powershell
python tools/godot/generate_barbatos_prop_prefabs.py
```

Generated scenes go to:

```text
scenes/props/barbatos_props/
```

Each generated scene is a `StaticBody3D` with:

- `Visual`: the exported GLB instance.
- `CollisionShape3D`: a starter box collider you can resize in the Inspector.
- `ToonTextureStyle3D`: the shared prototype toon material pass.
