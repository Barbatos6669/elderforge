"""Create editable source and runtime exports for one-handed sword placeholders.

Run with Blender from the project root:

    blender --background --python tools/blender/create_one_handed_sword_tier_assets.py -- --force

The generated .blend files are artist-owned placeholders. After this initial
pass, edit each tier's .blend directly and use
export_one_handed_sword_tier_asset.py to refresh only that tier's GLB.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SWORD_ROOT = PROJECT_ROOT / "assets" / "equipment" / "weapons" / "one_handed_swords"

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

TIER_NAMES = {
    1: "Crude",
    2: "Rough",
    3: "Sturdy",
    4: "Forged",
    5: "Hardened",
    6: "Runed",
    7: "Sunsteel",
    8: "Elder",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing tier .blend and .glb files.")
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
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness

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
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_prism(
    name: str,
    xz_points: list[tuple[float, float]],
    depth: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    half_depth = depth * 0.5
    vertices = [(x, -half_depth, z) for x, z in xz_points]
    vertices.extend((x, half_depth, z) for x, z in xz_points)

    count = len(xz_points)
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


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_torus(
    name: str,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    major_radius: float = 0.06,
    minor_radius: float = 0.012,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=8,
        minor_segments=4,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def build_sword(tier: int) -> bpy.types.Object:
    tier_name = TIER_NAMES[tier]
    blade_color = TIER_COLORS[tier]
    blade = make_material(f"T{tier}_Sword_{tier_name}_Blade", blade_color, metallic=0.45, roughness=0.34)
    edge = make_material(f"T{tier}_Sword_BrightEdge", (0.94, 0.92, 0.86, 1.0), metallic=0.35, roughness=0.28)
    guard = make_material(f"T{tier}_Sword_Guard", (0.18, 0.17, 0.15, 1.0), metallic=0.55, roughness=0.32)
    grip = make_material(f"T{tier}_Sword_LeatherGrip", (0.30, 0.14, 0.06, 1.0), roughness=0.8)

    root = bpy.data.objects.new(f"T{tier}OneHandedSword", None)
    bpy.context.scene.collection.objects.link(root)

    parts: list[bpy.types.Object] = []
    blade_points = [
        (-0.055, 0.06),
        (-0.085, 0.50),
        (-0.058, 1.04),
        (0.0, 1.26),
        (0.058, 1.04),
        (0.085, 0.50),
        (0.055, 0.06),
    ]
    parts.append(add_prism("Blade", blade_points, 0.035, blade))

    fuller_points = [
        (-0.010, 0.18),
        (-0.018, 0.90),
        (0.0, 1.08),
        (0.018, 0.90),
        (0.010, 0.18),
    ]
    parts.append(add_prism("Fuller", fuller_points, 0.039, edge))

    left_edge_points = [
        (-0.080, 0.16),
        (-0.063, 0.98),
        (-0.037, 1.12),
        (-0.050, 0.34),
    ]
    right_edge_points = [(-x, z) for x, z in left_edge_points]
    parts.append(add_prism("LeftBladeEdge", left_edge_points, 0.041, edge))
    parts.append(add_prism("RightBladeEdge", right_edge_points, 0.041, edge))

    parts.append(add_box("Guard", (0.56, 0.10, 0.08), (0.0, 0.0, 0.03), guard))
    parts.append(add_box("Grip", (0.10, 0.10, 0.36), (0.0, 0.0, -0.20), grip))
    parts.append(add_torus("TopGripRing", (0.0, 0.0, -0.04), guard, major_radius=0.065, minor_radius=0.010))
    parts.append(add_torus("BottomGripRing", (0.0, 0.0, -0.36), guard, major_radius=0.065, minor_radius=0.010))
    parts.append(add_cylinder("Pommel", 0.085, 0.075, (0.0, 0.0, -0.45), guard, vertices=8))

    for part in parts:
        parent_keep_world(part, root)

    root["elderforge_note"] = f"T{tier} one-handed sword placeholder. Edit this blend and re-export t{tier}_one_handed_sword.glb."
    return root


def tier_paths(tier: int) -> tuple[Path, Path]:
    tier_root = SWORD_ROOT / f"t{tier}"
    return tier_root / "source" / f"t{tier}_one_handed_sword.blend", tier_root / "models" / f"t{tier}_one_handed_sword.glb"


def create_tier(tier: int, force: bool) -> None:
    blend_path, export_path = tier_paths(tier)
    if not force and (blend_path.exists() or export_path.exists()):
        print(f"Skipping T{tier}; pass --force to overwrite existing assets.")
        return

	blend_path.parent.mkdir(parents=True, exist_ok=True)
	export_path.parent.mkdir(parents=True, exist_ok=True)
	(blend_path.parent / ".gdignore").touch()
	for folder_name in ("textures", "materials", "vfx", "icons"):
		(SWORD_ROOT / f"t{tier}" / folder_name).mkdir(parents=True, exist_ok=True)

    clear_scene()
    root = build_sword(tier)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_hierarchy(root, export_path)
    print(f"Created {blend_path}")
    print(f"Exported {export_path}")


def main() -> None:
    args = parse_args()
    for tier in range(1, 9):
        create_tier(tier, args.force)


if __name__ == "__main__":
    main()
