# Tree Model Assets

This folder holds the editable source art and runtime exports for resource tree
models.

## T1-T8 Trees

Files:

- `t1_tree.blend`: Blender source file. Open this when designing or replacing
  the T1 tree.
- `t1_tree_trunk.glb`: runtime trunk export used by `Tier1Tree.tscn`.
- `t1_tree_leaves.glb`: runtime leaf/canopy export used by `Tier1Tree.tscn`.
- `t1_tree_stump.glb`: runtime depleted-stump export used by `Tier1Tree.tscn`.
- `source/t2_tree.blend` through `source/t8_tree.blend`: generated editable
  tier copies that use the T1 tree shape and tier-colored leaves.
- `t2_tree_trunk.glb` through `t8_tree_trunk.glb`: runtime trunk exports for
  higher tiers.
- `t2_tree_leaves.glb` through `t8_tree_leaves.glb`: tier-colored canopy
  exports.
- `t2_tree_stump.glb` through `t8_tree_stump.glb`: depleted-stump exports.

Inside `t1_tree.blend`, the full tree is split into editable pieces:

- `T1TreeFull`: root for the full tree.
- `Trunk`: main trunk mesh.
- `Leaves`: parent for the leaf cluster meshes.
- `T1TreeDepleted`: root for the depleted model.
- `DepletedStump`: stump mesh shown after the tree is depleted.

Keep the roots at world origin with the bottom of the model on the ground. The
Godot gameplay scene owns collision, hover, selection, gathering ticks, and
depletion behavior.

## Re-export Workflow

After editing `t1_tree.blend`, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/models/resources/trees/t1_tree.blend --python tools/blender/export_t1_tree_asset.py
```

That exports the trunk over `t1_tree_trunk.glb`, the canopy over
`t1_tree_leaves.glb`, and the stump over `t1_tree_stump.glb`. Godot will
reimport those paths and `Tier1Tree.tscn` will update automatically.

`tools/blender/create_t1_tree_asset.py` is only for regenerating the scripted
placeholder from scratch. It refuses to overwrite the `.blend` unless you pass
`-- --force`, because normal art edits should happen directly in Blender.

## Tier Variant Workflow

To copy the current T1 placeholder tree shape into T2-T8 and recolor the leaves,
run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_resource_tier_variants.py
```

This writes the generated tier source files into `source/` and exports the GLBs
used by `Tier2Tree.tscn` through `Tier8Tree.tscn`.
