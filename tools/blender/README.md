# Blender Tools

This folder contains optional Blender-side helpers for Elderforge art creation.
These tools are for modeling and preview only; Godot still owns the final
runtime shaders, colliders, scripts, and prefab setup.

## Elderforge Toon Shader Add-on

`elderforge_toon_shader_addon.py` creates Blender materials that resemble the
current Godot toon pass:

- stepped low-poly lighting
- warm shadow/highlight ramps
- optional black outline preview
- a few starter Elderforge material presets

### Install

1. Open Blender.
2. Go to `Edit > Preferences > Add-ons`.
3. Click `Install from Disk`.
4. Select `tools/blender/elderforge_toon_shader_addon.py`.
5. Enable `Elderforge Toon Modeling Shader`.

### Use

1. Open the `3D Viewport`.
2. Press `N` to open the right sidebar.
3. Open the `Elderforge` tab.
4. Click `Create Toon Presets`.
5. Select a mesh and click `Apply Toon to Selected`.
6. Click `Add Black Outline Preview` if you want the Godot-style black lines.

The outline is a Blender preview helper. Remove it before exporting a GLB, or
make sure your glTF export settings do not bake preview-only modifiers. Godot
adds its own runtime outline, so exported meshes should stay clean.

## Elderforge Low Poly Tree Generator

`elderforge_low_poly_tree_generator.py` generates editable tree parts:

- trunk
- branches
- leaves
- optional hidden depleted stump

The generator is intentionally simple and game-facing. It creates separate
objects inside one collection so trees can later be exported as clean `.glb`
parts for Godot resource nodes.

### Install

1. Open Blender.
2. Go to `Edit > Preferences > Add-ons`.
3. Click `Install from Disk`.
4. Select `tools/blender/elderforge_low_poly_tree_generator.py`.
5. Enable `Elderforge Low Poly Tree Generator`.

### Use

1. Open the `3D Viewport`.
2. Press `N` to open the right sidebar.
3. Open the `Elderforge` tab.
4. Adjust seed, height, trunk radius, canopy radius, colors, and cluster count.
5. Click `Generate Low Poly Tree`.

The tree appears at the 3D cursor. Leaves are a separate object and include an
`elderforge_can_derender` custom property so the Godot workflow can recognize
them later if we build import automation around it.

## Elderforge Low Poly Rock Generator

`elderforge_low_poly_rock_generator.py` generates editable rock and ore-node
parts:

- rock body
- optional accent crystals
- loose chips
- optional hidden depleted rubble

This is meant for quick Godot resource-node modeling. The generated pieces are
separate objects in one collection, so you can reshape the body, tint accents,
delete chips, or export parts independently.

### Install

1. Open Blender.
2. Go to `Edit > Preferences > Add-ons`.
3. Click `Install from Disk`.
4. Select `tools/blender/elderforge_low_poly_rock_generator.py`.
5. Enable `Elderforge Low Poly Rock Generator`.

### Use

1. Open the `3D Viewport`.
2. Press `N` to open the right sidebar.
3. Open the `Elderforge` tab.
4. Adjust seed, radius, height, lobes, roughness, colors, chips, and crystals.
5. Click `Generate Low Poly Rock`.

Use `Accent Crystals` for ore-style nodes and leave it off for normal stone
nodes like Moonchalk.
