# Blender Tools

Small repeatable Blender scripts live here.

## T1 Tree Generator

`create_t1_tree_asset.py` creates:

- `assets/models/resources/trees/t1_tree.blend`
- `assets/models/resources/trees/t1_tree_trunk.glb`
- `assets/models/resources/trees/t1_tree_leaves.glb`
- `assets/models/resources/trees/t1_tree_stump.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python tools/blender/create_t1_tree_asset.py -- --force
```

Use the script only when you want to regenerate the current low-poly placeholder
from code.

## T1 Tree Export

After editing the Blender source file by hand, export without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/models/resources/trees/t1_tree.blend --python tools/blender/export_t1_tree_asset.py
```

That writes over the same `.glb` paths so the Godot scene keeps its gameplay
wiring.

## T1 Rock Generator

`create_t1_rock_asset.py` creates:

- `assets/models/resources/rocks/t1_rock.blend`
- `assets/models/resources/rocks/t1_rock_full.glb`
- `assets/models/resources/rocks/t1_rock_depleted.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python tools/blender/create_t1_rock_asset.py -- --force
```

Use the script only when you want to regenerate the current low-poly placeholder
from code.

## T1 Rock Export

After editing the Blender source file by hand, export without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/models/resources/rocks/t1_rock.blend --python tools/blender/export_t1_rock_asset.py
```

That writes over the same `.glb` paths so `Tier1Rock.tscn` keeps its gameplay
wiring.

## Axe Tool Tier Generator

`create_axe_tier_assets.py` creates editable placeholders for all eight axe
tiers:

- `assets/equipment/tools/axes/t1/source/t1_axe.blend`
- `assets/equipment/tools/axes/t1/models/t1_axe.glb`
- ...
- `assets/equipment/tools/axes/t8/source/t8_axe.blend`
- `assets/equipment/tools/axes/t8/models/t8_axe.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python tools/blender/create_axe_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Axe Tool Tier Export

After editing one axe tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background assets/equipment/tools/axes/t4/source/t4_axe.blend --python tools/blender/export_axe_tier_asset.py
```

That writes over `assets/equipment/tools/axes/t4/models/t4_axe.glb`, so
`Tier4Axe.tscn` and item definitions keep their prefab references.
