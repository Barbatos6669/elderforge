# Ore Model Assets

This folder holds the editable source art and runtime exports for ore resource
nodes.

## T1-T8 Ores

Files:

- `source/t1_ore.blend`: Blender source file. Open this when designing or
  replacing the T1 ore node.
- `t1_ore_full.glb`: runtime full-ore export used by `Tier1Ore.tscn`.
- `t1_ore_depleted.glb`: runtime depleted-rubble export used by
  `Tier1Ore.tscn`.
- `source/t2_ore.blend` through `source/t8_ore.blend`: generated editable tier
  copies that use the T1 ore shape and tier-colored ore facets.
- `t2_ore_full.glb` through `t8_ore_full.glb`: full-ore exports for higher
  tiers.
- `t2_ore_depleted.glb` through `t8_ore_depleted.glb`: depleted-rubble exports
  for higher tiers.

Inside `source/t1_ore.blend`, the ore is split into gameplay states:

- `T1OreFull`: full gatherable ore node.
- `T1OreDepleted`: depleted rubble node shown after all gather ticks are used.

Keep the roots at world origin with the bottom of the model on the ground. The
Godot gameplay scene owns collision, hover, selection, gathering ticks, and
depletion behavior.

## Re-export Workflow

After editing `source/t1_ore.blend`, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/resources/ores/source/t1_ore.blend --python tools/blender/export_t1_ore_asset.py
```

That exports the full ore over `t1_ore_full.glb` and the depleted rubble over
`t1_ore_depleted.glb`. Godot will reimport those paths and `Tier1Ore.tscn`
will update automatically.

`tools/blender/create_t1_ore_asset.py` is only for regenerating the scripted
placeholder from scratch. It refuses to overwrite the `.blend` unless you pass
`-- --force`, because normal art edits should happen directly in Blender.

## Tier Variant Workflow

To copy the current T1 placeholder ore shape into T2-T8 and recolor the ore
facets, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_resource_tier_variants.py
```

This writes the generated tier source files into `source/` and exports the GLBs
used by `Tier2Ore.tscn` through `Tier8Ore.tscn`.
