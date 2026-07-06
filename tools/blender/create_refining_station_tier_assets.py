"""Create editable Blender source assets for refining and crafting stations.

Run from the project root:

    blender --background --python tools/blender/create_refining_station_tier_assets.py -- --force

The generated files are intentionally simple, low-poly placeholders. They give
each station tier an artist-owned .blend file now, so future redesign work can
start from the folder instead of rebuilding the source pipeline later.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
STATION_ROOT = PROJECT_ROOT / "assets" / "models" / "refining_stations"

TIER_COLORS = {
    1: (0.72, 0.72, 0.72, 1.0),
    2: (0.72, 0.50, 0.30, 1.0),
    3: (0.20, 0.62, 0.25, 1.0),
    4: (0.20, 0.42, 0.82, 1.0),
    5: (0.78, 0.18, 0.16, 1.0),
    6: (0.92, 0.48, 0.14, 1.0),
    7: (0.95, 0.82, 0.18, 1.0),
    8: (0.94, 0.94, 0.90, 1.0),
}

FAMILIES = {
    "sawmills": {
        "file_stem": "sawmill",
        "root_stem": "Sawmill",
        "display": "Sawmill",
    },
    "stonecutters": {
        "file_stem": "stonecutter",
        "root_stem": "Stonecutter",
        "display": "Stonecutter",
    },
    "smelters": {
        "file_stem": "smelter",
        "root_stem": "Smelter",
        "display": "Smelter",
    },
    "looms": {
        "file_stem": "loom",
        "root_stem": "Loom",
        "display": "Loom",
    },
    "toolmakers": {
        "file_stem": "toolmaker",
        "root_stem": "Toolmaker",
        "display": "Tool Maker",
    },
    "weapon_smiths": {
        "file_stem": "weapon_smith",
        "root_stem": "WeaponSmith",
        "display": "Weapon Smith",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing station source and GLB files.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in __import__("sys").argv:
        return []
    return __import__("sys").argv[__import__("sys").argv.index("--") + 1 :]


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    for collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.collections,
        bpy.data.images,
    ):
        for datablock in list(collection):
            collection.remove(datablock)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.72,
    emission: tuple[float, float, float, float] | None = None,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
        if emission is not None:
            shader.inputs["Emission Color"].default_value = emission
            shader.inputs["Emission Strength"].default_value = 0.75

    return material


def set_flat_shading(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_hierarchy(root: bpy.types.Object, path: Path) -> None:
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )


def add_box(
    name: str,
    scale: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    vertices: int = 16,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_prism(
    name: str,
    xy_points: list[tuple[float, float]],
    depth: float,
    z_center: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    half_depth = depth * 0.5
    vertices = [(x, y, z_center - half_depth) for x, y in xy_points]
    vertices.extend((x, y, z_center + half_depth) for x, y in xy_points)

    count = len(xy_points)
    faces: list[tuple[int, ...]] = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def make_materials(tier: int) -> dict[str, bpy.types.Material]:
    return {
        "stone": make_material("Stone", (0.34, 0.33, 0.30, 1.0), roughness=0.82),
        "dark_stone": make_material("DarkStone", (0.21, 0.20, 0.18, 1.0), roughness=0.9),
        "wood": make_material("Wood", (0.46, 0.25, 0.11, 1.0), roughness=0.75),
        "cut_wood": make_material("CutWood", (0.88, 0.56, 0.21, 1.0), roughness=0.68),
        "metal": make_material("Metal", (0.60, 0.61, 0.59, 1.0), metallic=0.35, roughness=0.32),
        "dark_metal": make_material("DarkMetal", (0.24, 0.24, 0.23, 1.0), metallic=0.4, roughness=0.34),
        "cloth": make_material("Cloth", (0.78, 0.70, 0.55, 1.0), roughness=0.86),
        "leather": make_material("Leather", (0.38, 0.17, 0.07, 1.0), roughness=0.82),
        "hot": make_material("HotForgeGlow", (0.95, 0.28, 0.08, 1.0), roughness=0.35, emission=(0.95, 0.18, 0.04, 1.0)),
        "accent": make_material(f"T{tier}TierAccent", TIER_COLORS[tier], metallic=0.1, roughness=0.52),
    }


def add_foundation(parts: list[bpy.types.Object], materials: dict[str, bpy.types.Material]) -> None:
    parts.append(add_box("FootprintBase", (3.8, 3.8, 0.14), (0.0, 0.0, 0.07), materials["dark_stone"]))


def add_tier_badge(parts: list[bpy.types.Object], tier: int, materials: dict[str, bpy.types.Material]) -> None:
    height = 0.22 + tier * 0.035
    parts.append(add_box("TierFrontTrim", (3.82, 0.10, 0.10), (0.0, -1.93, height), materials["accent"]))
    parts.append(add_box("TierBackTrim", (3.82, 0.10, 0.10), (0.0, 1.93, height), materials["accent"]))
    parts.append(add_box("TierLeftTrim", (0.10, 3.82, 0.10), (-1.93, 0.0, height), materials["accent"]))
    parts.append(add_box("TierRightTrim", (0.10, 3.82, 0.10), (1.93, 0.0, height), materials["accent"]))
    parts.append(add_cylinder("TierEmblem", 0.20, 0.06, (0.0, -1.78, 1.05), materials["accent"], vertices=8, rotation=(1.5708, 0.0, 0.0)))


def build_sawmill(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    parts.append(add_box("TableTop", (3.2, 1.25, 0.22), (0.0, 0.0, 0.82), materials["wood"]))
    for x in (-1.35, 1.35):
        for y in (-0.46, 0.46):
            parts.append(add_box("TableLeg", (0.22, 0.22, 0.72), (x, y, 0.42), materials["wood"]))
    parts.append(add_box("LeftRail", (3.45, 0.08, 0.08), (0.0, -0.44, 0.98), materials["accent"]))
    parts.append(add_box("RightRail", (3.45, 0.08, 0.08), (0.0, 0.44, 0.98), materials["accent"]))
    parts.append(add_cylinder("SawBlade", 0.52, 0.055, (0.15, 0.0, 1.14), materials["metal"], vertices=48, rotation=(0.0, 1.5708, 0.0)))
    parts.append(add_cylinder("BladeHub", 0.18, 0.08, (0.15, 0.0, 1.14), materials["accent"], vertices=16, rotation=(0.0, 1.5708, 0.0)))
    parts.append(add_cylinder("InputLogA", 0.18, 1.65, (-0.65, -0.16, 1.03), materials["wood"], vertices=12, rotation=(0.0, 1.5708, 0.0)))
    parts.append(add_cylinder("InputLogB", 0.18, 1.65, (-0.72, 0.18, 1.03), materials["wood"], vertices=12, rotation=(0.0, 1.5708, 0.0)))
    for y, z in ((0.22, 1.02), (0.22, 1.20), (-0.22, 1.02)):
        parts.append(add_box("OutputPlank", (1.35, 0.32, 0.16), (0.86, y, z), materials["cut_wood"]))
    add_tier_badge(parts, tier, materials)
    return parts


def build_stonecutter(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    parts.append(add_box("WorkBlock", (1.35, 1.0, 0.58), (-0.55, 0.0, 0.52), materials["stone"]))
    parts.append(add_box("CutLine", (1.42, 0.05, 0.62), (-0.55, 0.0, 0.84), materials["accent"]))
    parts.append(add_box("InputStonePileA", (0.9, 0.72, 0.42), (0.75, -0.38, 0.36), materials["stone"]))
    parts.append(add_box("InputStonePileB", (0.72, 0.62, 0.34), (1.02, 0.32, 0.32), materials["stone"]))
    parts.append(add_box("OutputBlockA", (0.68, 0.55, 0.38), (0.42, 0.78, 0.32), materials["dark_stone"]))
    parts.append(add_box("OutputBlockB", (0.62, 0.48, 0.32), (1.16, 0.82, 0.28), materials["dark_stone"]))
    add_tier_badge(parts, tier, materials)
    return parts


def build_smelter(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    parts.append(add_box("FurnaceBody", (1.55, 1.35, 1.12), (-0.35, 0.0, 0.68), materials["stone"]))
    parts.append(add_box("HearthGlow", (1.05, 0.12, 0.42), (-0.35, -0.70, 0.64), materials["hot"]))
    parts.append(add_cylinder("Chimney", 0.24, 1.1, (-0.35, 0.18, 1.62), materials["dark_stone"], vertices=12))
    parts.append(add_box("IngotTray", (1.1, 0.75, 0.18), (0.95, -0.48, 0.48), materials["dark_metal"]))
    for index in range(4):
        parts.append(add_box("Ingot", (0.32, 0.16, 0.10), (0.72 + index * 0.18, -0.48, 0.62), materials["metal"]))
    add_tier_badge(parts, tier, materials)
    return parts


def build_loom(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    for x in (-1.1, 1.1):
        for y in (-0.55, 0.55):
            parts.append(add_box("FramePost", (0.16, 0.16, 1.35), (x, y, 0.74), materials["wood"]))
    parts.append(add_box("FrontBeam", (2.5, 0.14, 0.16), (0.0, -0.62, 1.42), materials["wood"]))
    parts.append(add_box("BackBeam", (2.5, 0.14, 0.16), (0.0, 0.62, 1.42), materials["wood"]))
    parts.append(add_box("ClothSheet", (1.7, 0.08, 1.0), (0.0, -0.04, 0.92), materials["cloth"], rotation=(0.28, 0.0, 0.0)))
    parts.append(add_cylinder("ClothRoll", 0.20, 1.8, (0.0, 0.62, 0.92), materials["cloth"], vertices=16, rotation=(0.0, 1.5708, 0.0)))
    parts.append(add_box("Shuttle", (0.64, 0.12, 0.12), (0.62, -0.50, 0.72), materials["accent"]))
    add_tier_badge(parts, tier, materials)
    return parts


def build_toolmaker(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    parts.append(add_box("Workbench", (2.9, 1.12, 0.28), (0.0, 0.0, 0.82), materials["wood"]))
    for x in (-1.25, 1.25):
        for y in (-0.4, 0.4):
            parts.append(add_box("BenchLeg", (0.20, 0.20, 0.72), (x, y, 0.42), materials["wood"]))
    parts.append(add_box("AnvilBody", (0.86, 0.42, 0.28), (-0.58, -0.05, 1.06), materials["dark_metal"]))
    parts.append(add_box("AnvilTop", (1.16, 0.34, 0.16), (-0.58, -0.05, 1.28), materials["dark_metal"]))
    parts.append(add_box("ToolRack", (2.7, 0.14, 0.14), (0.0, 0.68, 1.54), materials["accent"]))
    parts.append(add_box("ToolBlankA", (0.16, 0.08, 0.72), (0.58, 0.05, 1.13), materials["metal"], rotation=(0.0, 0.0, 0.20)))
    parts.append(add_box("ToolBlankB", (0.16, 0.08, 0.72), (0.90, -0.18, 1.13), materials["metal"], rotation=(0.0, 0.0, -0.25)))
    add_tier_badge(parts, tier, materials)
    return parts


def build_weapon_smith(tier: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    add_foundation(parts, materials)
    parts.append(add_box("ForgeBody", (1.3, 1.1, 0.85), (-0.8, -0.15, 0.55), materials["stone"]))
    parts.append(add_box("ForgeGlow", (0.95, 0.70, 0.18), (-0.8, 0.43, 0.72), materials["hot"]))
    parts.append(add_box("AnvilBody", (0.9, 0.42, 0.28), (0.65, -0.45, 0.86), materials["dark_metal"]))
    parts.append(add_box("AnvilTop", (1.2, 0.34, 0.16), (0.65, -0.45, 1.08), materials["dark_metal"]))
    parts.append(add_box("WorkTable", (1.75, 0.85, 0.20), (0.55, 0.55, 0.76), materials["wood"]))
    parts.append(add_box("RackPostL", (0.16, 0.16, 0.86), (-1.45, 1.0, 0.65), materials["wood"]))
    parts.append(add_box("RackPostR", (0.16, 0.16, 0.86), (1.45, 1.0, 0.65), materials["wood"]))
    blade_points = [(-0.08, 0.0), (-0.04, 0.66), (0.0, 0.82), (0.04, 0.66), (0.08, 0.0)]
    sword = add_prism("SwordBlankBlade", blade_points, 0.035, 1.01, materials["metal"])
    sword.location = (0.42, 0.55, 0.0)
    sword.rotation_euler[2] = 1.5708
    parts.append(sword)
    parts.append(add_box("SwordBlankGuard", (0.44, 0.06, 0.08), (-0.05, 0.55, 1.0), materials["metal"], rotation=(0.0, 0.0, 1.5708)))
    add_tier_badge(parts, tier, materials)
    return parts


BUILDERS = {
    "sawmills": build_sawmill,
    "stonecutters": build_stonecutter,
    "smelters": build_smelter,
    "looms": build_loom,
    "toolmakers": build_toolmaker,
    "weapon_smiths": build_weapon_smith,
}


def build_station(family: str, tier: int) -> bpy.types.Object:
    family_info = FAMILIES[family]
    root = bpy.data.objects.new(f"T{tier}{family_info['root_stem']}", None)
    bpy.context.scene.collection.objects.link(root)

    materials = make_materials(tier)
    parts = BUILDERS[family](tier, materials)
    for part in parts:
        parent_keep_world(part, root)

    root["elderforge_note"] = (
        f"T{tier} {family_info['display']} placeholder source. "
        f"Edit this blend and export t{tier}_{family_info['file_stem']}.glb."
    )
    return root


def tier_paths(family: str, tier: int) -> tuple[Path, Path]:
    file_stem = FAMILIES[family]["file_stem"]
    tier_root = STATION_ROOT / family / f"t{tier}"
    return tier_root / "source" / f"t{tier}_{file_stem}.blend", tier_root / "models" / f"t{tier}_{file_stem}.glb"


def create_tier(family: str, tier: int, force: bool) -> None:
    blend_path, export_path = tier_paths(family, tier)
    if not force and (blend_path.exists() or export_path.exists()):
        print(f"Skipping {family} T{tier}; pass --force to overwrite existing assets.")
        return

	blend_path.parent.mkdir(parents=True, exist_ok=True)
	export_path.parent.mkdir(parents=True, exist_ok=True)
	(blend_path.parent / ".gdignore").touch()
	for folder_name in ("textures", "materials", "vfx", "icons"):
		(STATION_ROOT / family / f"t{tier}" / folder_name).mkdir(parents=True, exist_ok=True)

    clear_scene()
    root = build_station(family, tier)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_hierarchy(root, export_path)
    print(f"Created {blend_path}")
    print(f"Exported {export_path}")


def main() -> None:
    args = parse_args()
    for family in FAMILIES:
        for tier in range(1, 9):
            create_tier(family, tier, args.force)


if __name__ == "__main__":
    main()
