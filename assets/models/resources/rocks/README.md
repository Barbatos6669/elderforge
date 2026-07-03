# Rock Model Assets

This folder holds the editable source art and runtime exports for stone resource
rocks.

## T1-T8 Rocks

Files:

- `t1_rock.blend`: Blender source file. Open this when designing or replacing
  the T1 rock.
- `t1_rock_full.glb`: runtime full-rock export used by `Tier1Rock.tscn`.
- `t1_rock_depleted.glb`: runtime depleted-rubble export used by
  `Tier1Rock.tscn`.
- `source/t2_rock.blend` through `source/t8_rock.blend`: generated editable
  tier copies that use the T1 rock shape and tier-colored stone material.
- `t2_rock_full.glb` through `t8_rock_full.glb`: full-rock exports for higher
  tiers.
- `t2_rock_depleted.glb` through `t8_rock_depleted.glb`: depleted-rubble
  exports for higher tiers.

Inside `t1_rock.blend`, the rock is split into gameplay states:

- `T1RockFull`: full gatherable rock node.
- `T1RockDepleted`: depleted rubble node shown after all gather ticks are used.

Keep the roots at world origin with the bottom of the model on the ground. The
Godot gameplay scene owns collision, hover, selection, gathering ticks, and
depletion behavior.

## Re-export Workflow

After editing `t1_rock.blend`, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/models/resources/rocks/t1_rock.blend --python tools/blender/export_t1_rock_asset.py
```

That exports the full rock over `t1_rock_full.glb` and the depleted rubble over
`t1_rock_depleted.glb`. Godot will reimport those paths and `Tier1Rock.tscn`
will update automatically.

`tools/blender/create_t1_rock_asset.py` is only for regenerating the scripted
placeholder from scratch. It refuses to overwrite the `.blend` unless you pass
`-- --force`, because normal art edits should happen directly in Blender.

## Tier Variant Workflow

To copy the current T1 placeholder rock shape into T2-T8 and recolor the stone,
run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_resource_tier_variants.py
```

This writes the generated tier source files into `source/` and exports the GLBs
used by `Tier2Rock.tscn` through `Tier8Rock.tscn`.
