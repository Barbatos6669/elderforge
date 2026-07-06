# Barbatos Prop Prefabs

Reusable scenes for custom Elderforge props made under
`assets/models/props/barbatos_props/`.

Run this after adding or replacing a runtime `.glb` or `.gltf`:

```powershell
python tools/godot/generate_barbatos_prop_prefabs.py
```

The generated scenes are intentionally light wrappers:

- `StaticBody3D` root so props can have collision.
- `Visual` child that instances the runtime model.
- `CollisionShape3D` with a starter box collider for quick Inspector tuning.
- `ToonTextureStyle3D` material pass so custom props match the prototype style.
