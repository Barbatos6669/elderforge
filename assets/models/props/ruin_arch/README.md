# Low-Poly Ruin Arch

Source-backed world prop inspired by a ruined magical stone gateway.

## Files

- `source/low_poly_ruin_arch.blend`: editable Blender source.
- `models/low_poly_ruin_arch.glb`: runtime export used by the Godot prefab.
- `scenes/props/ruin_arch/LowPolyRuinArch.tscn`: drop-in Godot prefab with
  simple collision.

The visible stair mesh stays low-poly and stepped, but the prefab uses an
invisible `StairRampCollision` shape so the player walks through the arch on a
smooth gameplay ramp. Pillar collision is intentionally looser than the visual
mesh so the doorway feels easy to pass through during playtesting.

## Editing Workflow

1. Open `source/low_poly_ruin_arch.blend` in Blender.
2. Edit the stones, runes, vines, or scale.
3. Re-export with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/props/ruin_arch/source/low_poly_ruin_arch.blend --python tools/blender/export_low_poly_ruin_arch_asset.py
```

The prefab keeps pointing at the same GLB path, so gameplay scenes update after
Godot reimports the model.
