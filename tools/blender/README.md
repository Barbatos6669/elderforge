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

## T1 Ore Generator

`create_t1_ore_asset.py` creates:

- `assets/models/resources/ores/source/t1_ore.blend`
- `assets/models/resources/ores/t1_ore_full.glb`
- `assets/models/resources/ores/t1_ore_depleted.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_t1_ore_asset.py -- --force
```

Use the script only when you want to regenerate the current low-poly placeholder
from code.

## T1 Ore Export

After editing the Blender source file by hand, export without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/resources/ores/source/t1_ore.blend --python tools/blender/export_t1_ore_asset.py
```

That writes over the same `.glb` paths so `Tier1Ore.tscn` keeps its gameplay
wiring.

## T1 Fiber Generator

`create_t1_fiber_asset.py` creates:

- `assets/models/resources/fibers/source/t1_fiber.blend`
- `assets/models/resources/fibers/t1_fiber_full.glb`
- `assets/models/resources/fibers/t1_fiber_depleted.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_t1_fiber_asset.py -- --force
```

Use the script only when you want to regenerate the current low-poly placeholder
from code.

## T1 Fiber Export

After editing the Blender source file by hand, export without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/resources/fibers/source/t1_fiber.blend --python tools/blender/export_t1_fiber_asset.py
```

That writes over the same `.glb` paths so `Tier1Fiber.tscn` keeps its gameplay
wiring.

## Resource Tier Variant Generator

`create_resource_tier_variants.py` copies the current T1 placeholder shapes for
trees, rocks, ore, and fiber into T2-T8 source blends, recolors the tier-facing
materials, and exports the runtime GLBs used by the tiered gathering scenes.

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_resource_tier_variants.py
```

This is useful while the resource art is still placeholder-driven. Once a tier
gets hand-authored art, edit that tier's `.blend` directly and export the
matching GLBs instead of regenerating from T1.

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

## Low-Poly Ruin Arch Generator

`create_low_poly_ruin_arch_asset.py` creates the editable source and runtime
export for the starter-city ruin arch prop:

- `assets/models/props/ruin_arch/source/low_poly_ruin_arch.blend`
- `assets/models/props/ruin_arch/models/low_poly_ruin_arch.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_low_poly_ruin_arch_asset.py -- --force
```

Use this only when you want to rebuild the scripted placeholder from scratch.

## Low-Poly Ruin Arch Export

After editing the arch by hand, export without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/props/ruin_arch/source/low_poly_ruin_arch.blend --python tools/blender/export_low_poly_ruin_arch_asset.py
```

That writes over the same runtime GLB used by
`scenes/props/ruin_arch/LowPolyRuinArch.tscn`.

## Stylized Nature MegaKit Import

`import_stylized_nature_megakit.py` converts the imported Quaternius nature pack
from raw FBX files into our normal editable-source workflow:

- `assets/models/environment/stylized_nature_megakit/source/*.blend`
- `assets/models/environment/stylized_nature_megakit/models/*.gltf`
- `assets/models/environment/stylized_nature_megakit/models/*.bin`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_stylized_nature_megakit.py -- --force
```

This pack uses `.gltf` instead of `.glb` so all models can share the same
texture files under `textures/`. That avoids embedding duplicate bark, leaf, and
rock textures into every model.

## Stylized Nature MegaKit Export

After editing one nature source file by hand, export only that asset:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_stylized_nature_megakit.py -- --asset common_tree_1
```

To export every edited source:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_stylized_nature_megakit.py -- --all
```

## Fantasy Props MegaKit Import

`import_fantasy_props_megakit.py` converts the imported Quaternius fantasy prop
pack from raw FBX files into our normal editable-source workflow:

- `assets/models/props/fantasy_props_megakit/source/*.blend`
- `assets/models/props/fantasy_props_megakit/models/*.gltf`
- `assets/models/props/fantasy_props_megakit/models/*.bin`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_fantasy_props_megakit.py -- --force
```

This pack uses `.gltf` instead of `.glb` so all props can share the same large
texture atlases under `textures/`.

## Fantasy Props MegaKit Export

After editing one fantasy prop source file by hand, export only that asset:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_fantasy_props_megakit.py -- --asset anvil
```

To export every edited source:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_fantasy_props_megakit.py -- --all
```

## Modular Prototyping Assets Import

`import_modular_prototyping_assets.py` converts the CC0 Free 3D Modular Game
Assets For Prototyping pack from raw FBX files into our normal editable-source
workflow:

- `assets/models/props/free_3d_modular_game_assets_for_prototyping/source/*.blend`
- `assets/models/props/free_3d_modular_game_assets_for_prototyping/models/*.gltf`
- `assets/models/props/free_3d_modular_game_assets_for_prototyping/models/*.bin`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_modular_prototyping_assets.py -- --force
```

## Modular Prototyping Assets Export

After editing one modular source file by hand, export only that asset:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_modular_prototyping_assets.py -- --asset wall
```

To export every edited source:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_modular_prototyping_assets.py -- --all
```

## Hammer Tool Tier Generator

`create_hammer_tier_assets.py` creates editable placeholders for all eight
stone-gathering hammer tiers:

- `assets/equipment/tools/hammers/t1/source/t1_hammer.blend`
- `assets/equipment/tools/hammers/t1/models/t1_hammer.glb`
- ...
- `assets/equipment/tools/hammers/t8/source/t8_hammer.blend`
- `assets/equipment/tools/hammers/t8/models/t8_hammer.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_hammer_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Hammer Tool Tier Export

After editing one hammer tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/hammers/t4/source/t4_hammer.blend --python tools/blender/export_hammer_tier_asset.py
```

That writes over `assets/equipment/tools/hammers/t4/models/t4_hammer.glb`, so
`Tier4Hammer.tscn` and item definitions keep their prefab references.

## Pickaxe Tool Tier Generator

`create_pickaxe_tier_assets.py` creates editable placeholders for all eight
ore-gathering pickaxe tiers:

- `assets/equipment/tools/pickaxes/t1/source/t1_pickaxe.blend`
- `assets/equipment/tools/pickaxes/t1/models/t1_pickaxe.glb`
- ...
- `assets/equipment/tools/pickaxes/t8/source/t8_pickaxe.blend`
- `assets/equipment/tools/pickaxes/t8/models/t8_pickaxe.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_pickaxe_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Pickaxe Tool Tier Export

After editing one pickaxe tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/pickaxes/t4/source/t4_pickaxe.blend --python tools/blender/export_pickaxe_tier_asset.py
```

That writes over `assets/equipment/tools/pickaxes/t4/models/t4_pickaxe.glb`, so
`Tier4Pickaxe.tscn` and item definitions keep their prefab references.

## Copy Edited T1 Pickaxe To Tiers

When T1 is being used as the shared placeholder shape, copy its edited mesh to
all other pickaxe tiers while keeping each tier's metal color:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/copy_pickaxe_t1_mesh_to_tiers.py
```

This leaves `t1_pickaxe.blend` as the source of truth, saves updated source
files for T2-T8, and exports all eight `t#_pickaxe.glb` files.

## Sickle Tool Tier Generator

`create_sickle_tier_assets.py` creates editable placeholders for all eight
fiber-gathering sickle tiers:

- `assets/equipment/tools/sickles/t1/source/t1_sickle.blend`
- `assets/equipment/tools/sickles/t1/models/t1_sickle.glb`
- ...
- `assets/equipment/tools/sickles/t8/source/t8_sickle.blend`
- `assets/equipment/tools/sickles/t8/models/t8_sickle.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_sickle_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Sickle Tool Tier Export

After editing one sickle tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/sickles/t4/source/t4_sickle.blend --python tools/blender/export_sickle_tier_asset.py
```

That writes over `assets/equipment/tools/sickles/t4/models/t4_sickle.glb`, so
`Tier4Sickle.tscn` and item definitions keep their prefab references.

## Copy Edited T1 Sickle To Tiers

When T1 is being used as the shared placeholder shape, copy its edited mesh to
all other sickle tiers while keeping each tier's blade color:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/copy_sickle_t1_mesh_to_tiers.py
```

This leaves `t1_sickle.blend` as the source of truth, saves updated source
files for T2-T8, and exports all eight `t#_sickle.glb` files.

## Skinning Knife Tool Tier Generator

`create_skinning_knife_tier_assets.py` creates editable placeholders for all
eight hide-gathering skinning knife tiers:

- `assets/equipment/tools/skinning_knives/t1/source/t1_skinning_knife.blend`
- `assets/equipment/tools/skinning_knives/t1/models/t1_skinning_knife.glb`
- ...
- `assets/equipment/tools/skinning_knives/t8/source/t8_skinning_knife.blend`
- `assets/equipment/tools/skinning_knives/t8/models/t8_skinning_knife.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_skinning_knife_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Skinning Knife Tool Tier Export

After editing one skinning knife tier by hand, export that tier without
rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/tools/skinning_knives/t4/source/t4_skinning_knife.blend --python tools/blender/export_skinning_knife_tier_asset.py
```

That writes over
`assets/equipment/tools/skinning_knives/t4/models/t4_skinning_knife.glb`, so
`Tier4SkinningKnife.tscn` and item definitions keep their prefab references.

## Copy Edited T1 Skinning Knife To Tiers

When T1 is being used as the shared placeholder shape, copy its edited mesh to
all other skinning knife tiers while keeping each tier's blade color:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/copy_skinning_knife_t1_mesh_to_tiers.py
```

This leaves `t1_skinning_knife.blend` as the source of truth, saves updated
source files for T2-T8, and exports all eight `t#_skinning_knife.glb` files.

## One-Handed Sword Tier Generator

`create_one_handed_sword_tier_assets.py` creates editable placeholders for all
eight one-handed sword tiers:

- `assets/equipment/weapons/one_handed_swords/t1/source/t1_one_handed_sword.blend`
- `assets/equipment/weapons/one_handed_swords/t1/models/t1_one_handed_sword.glb`
- ...
- `assets/equipment/weapons/one_handed_swords/t8/source/t8_one_handed_sword.blend`
- `assets/equipment/weapons/one_handed_swords/t8/models/t8_one_handed_sword.glb`

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_one_handed_sword_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly tier
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## One-Handed Sword Tier Export

After editing one sword tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/equipment/weapons/one_handed_swords/t4/source/t4_one_handed_sword.blend --python tools/blender/export_one_handed_sword_tier_asset.py
```

That writes over
`assets/equipment/weapons/one_handed_swords/t4/models/t4_one_handed_sword.glb`,
so `Tier4OneHandedSword.tscn` and item definitions keep their prefab references.

## Refining Station Tier Generator

`create_refining_station_tier_assets.py` creates editable placeholders for all
eight tiers of each station family:

- sawmills
- stonecutters
- smelters
- looms
- toolmakers
- weapon smiths

Run it from the project root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/create_refining_station_tier_assets.py -- --force
```

Use the script only when you want to regenerate the current low-poly station
placeholders from code. Normal art edits should happen in each tier's `.blend`
file.

## Refining Station Tier Export

After editing one station tier by hand, export that tier without rebuilding it:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background assets/models/refining_stations/sawmills/t4/source/t4_sawmill.blend --python tools/blender/export_refining_station_tier_asset.py
```

That writes over the matching GLB under `assets/models/refining_stations/`.
