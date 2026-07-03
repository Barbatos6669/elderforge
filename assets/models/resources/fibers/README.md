# Fiber Model Assets

This folder holds the editable source art and runtime exports for fiber resource
nodes.

## T1-T8 Fiber

Files:

- `source/t1_fiber.blend`: Blender source file. Open this when designing or
  replacing the T1 fiber node.
- `t1_fiber_full.glb`: runtime full-fiber export used by `Tier1Fiber.tscn`.
- `t1_fiber_depleted.glb`: runtime depleted cut-stem export used by
  `Tier1Fiber.tscn`.
- `source/t2_fiber.blend` through `source/t8_fiber.blend`: generated editable
  tier copies that use the T1 fiber shape and tier-colored cotton bolls.
- `t2_fiber_full.glb` through `t8_fiber_full.glb`: full-fiber exports for
  higher tiers.
- `t2_fiber_depleted.glb` through `t8_fiber_depleted.glb`: depleted cut-stem
  exports for higher tiers.

Inside `source/t1_fiber.blend`, the plant is split into gameplay states:

- `T1FiberFull`: full gatherable cotton/fiber plant.
- `T1FiberDepleted`: cut stems and leftovers shown after all gather ticks are
  used.

Keep the roots at world origin with the bottom of the model on the ground. The
Godot gameplay scene owns collision, hover, selection, gathering ticks, and
depletion behavior.

## Re-export Workflow

After editing `source/t1_fiber.blend`, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/resources/fibers/source/t1_fiber.blend --python tools/blender/export_t1_fiber_asset.py
```

That exports the full plant over `t1_fiber_full.glb` and the depleted plant over
`t1_fiber_depleted.glb`. Godot will reimport those paths and `Tier1Fiber.tscn`
will update automatically.

`tools/blender/create_t1_fiber_asset.py` is only for regenerating the scripted
placeholder from scratch. It refuses to overwrite the `.blend` unless you pass
`-- --force`, because normal art edits should happen directly in Blender.

## Tier Variant Workflow

To copy the current T1 placeholder fiber shape into T2-T8 and recolor the cotton
bolls, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_resource_tier_variants.py
```

This writes the generated tier source files into `source/` and exports the GLBs
used by `Tier2Fiber.tscn` through `Tier8Fiber.tscn`.
