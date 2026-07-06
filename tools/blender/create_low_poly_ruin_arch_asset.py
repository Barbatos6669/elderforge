"""Create the editable low-poly ruin arch source and runtime GLB.

Run from the project root:

    blender --background --python tools/blender/create_low_poly_ruin_arch_asset.py -- --force

The generated .blend is an artist-owned starting point. After hand-editing the
source, use export_low_poly_ruin_arch_asset.py to refresh the runtime GLB.
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = PROJECT_ROOT / "assets" / "models" / "props" / "ruin_arch"
BLEND_PATH = ASSET_ROOT / "source" / "low_poly_ruin_arch.blend"
EXPORT_PATH = ASSET_ROOT / "models" / "low_poly_ruin_arch.glb"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing ruin arch source and GLB.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    import sys

    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


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
    roughness: float = 0.86,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        if "Base Color" in shader.inputs:
            shader.inputs["Base Color"].default_value = color
        if "Roughness" in shader.inputs:
            shader.inputs["Roughness"].default_value = roughness
        if emission is not None:
            if "Emission Color" in shader.inputs:
                shader.inputs["Emission Color"].default_value = emission
            if "Emission Strength" in shader.inputs:
                shader.inputs["Emission Strength"].default_value = emission_strength

    return material


def set_flat_shading(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def add_box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    if parent is not None:
        parent_keep_world(obj, parent)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    vertices: int = 12,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
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
    if parent is not None:
        parent_keep_world(obj, parent)
    return obj


def add_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=18,
        minor_segments=4,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(material)
    set_flat_shading(obj)
    parent_keep_world(obj, parent)
    return obj


def add_xz_prism(
    name: str,
    xz_points: list[tuple[float, float]],
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object,
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
    obj.location = location
    obj.data.materials.append(material)
    set_flat_shading(obj)
    parent_keep_world(obj, parent)
    return obj


def add_cylinder_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    parent: bpy.types.Object,
    vertices: int = 5,
) -> bpy.types.Object:
    start_vec = Vector(start)
    end_vec = Vector(end)
    direction = end_vec - start_vec
    length = direction.length
    if length <= 0.001:
        raise ValueError(f"{name} vine segment has no length.")

    midpoint = start_vec + direction * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    set_flat_shading(obj)
    parent_keep_world(obj, parent)
    return obj


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


def build_pillar(
    root: bpy.types.Object,
    side: int,
    stone: bpy.types.Material,
    stone_dark: bpy.types.Material,
    moss: bpy.types.Material,
    rune: bpy.types.Material,
) -> None:
    rng = random.Random(100 + side)
    x_center = side * 2.45

    add_box(f"{'Right' if side > 0 else 'Left'}_Base_Plinth", (1.45, 1.15, 0.42), (x_center, 0.0, 0.21), stone_dark, parent=root)
    add_box(f"{'Right' if side > 0 else 'Left'}_Foot_Block", (1.25, 1.02, 0.32), (x_center, 0.0, 0.58), stone, parent=root)

    row_z = 0.88
    row = 0
    while row_z < 3.25:
        block_height = rng.choice((0.34, 0.38, 0.42))
        pieces = 2 if row % 2 == 0 else 3
        for column in range(pieces):
            width = 1.02 / pieces
            x_offset = (column - (pieces - 1) * 0.5) * width
            wobble = rng.uniform(-0.035, 0.035)
            depth = rng.uniform(0.84, 0.98)
            mat = stone if rng.random() > 0.32 else stone_dark
            add_box(
                f"{'Right' if side > 0 else 'Left'}_Pillar_Block_{row}_{column}",
                (width * rng.uniform(0.92, 1.05), depth, block_height),
                (x_center + x_offset + wobble, rng.uniform(-0.02, 0.02), row_z),
                mat,
                rotation=(0.0, rng.uniform(-0.035, 0.035), rng.uniform(-0.018, 0.018)),
                parent=root,
            )
        row_z += block_height
        row += 1

    add_box(f"{'Right' if side > 0 else 'Left'}_Top_Cap", (1.55, 1.12, 0.34), (x_center, 0.0, 3.42), stone_dark, parent=root)
    add_box(f"{'Right' if side > 0 else 'Left'}_Outer_Buttress", (0.35, 1.08, 2.35), (side * 3.15, 0.02, 1.82), stone_dark, parent=root)

    panel_x = x_center - side * 0.03
    add_box(f"{'Right' if side > 0 else 'Left'}_Rune_Panel_Back", (0.48, 0.05, 1.55), (panel_x, -0.535, 1.86), stone_dark, parent=root)
    add_box(f"{'Right' if side > 0 else 'Left'}_Rune_Panel_Glow", (0.055, 0.035, 1.18), (panel_x, -0.578, 1.86), rune, parent=root)

    for index in range(8):
        z = 1.22 + index * 0.16
        x = panel_x + rng.uniform(-0.12, 0.12)
        add_box(
            f"{'Right' if side > 0 else 'Left'}_Panel_Rune_{index}",
            (0.04, 0.03, rng.uniform(0.12, 0.23)),
            (x, -0.598, z),
            rune,
            rotation=(0.0, rng.uniform(-0.65, 0.65), 0.0),
            parent=root,
        )

    for index in range(5):
        add_box(
            f"{'Right' if side > 0 else 'Left'}_Moss_Patch_{index}",
            (rng.uniform(0.22, 0.48), 0.04, rng.uniform(0.05, 0.11)),
            (x_center + rng.uniform(-0.5, 0.5), -0.59, rng.uniform(0.8, 3.35)),
            moss,
            rotation=(0.0, rng.uniform(-0.15, 0.15), rng.uniform(-0.2, 0.2)),
            parent=root,
        )


def build_arch_ring(root: bpy.types.Object, stone: bpy.types.Material, stone_dark: bpy.types.Material, rune: bpy.types.Material) -> None:
    center_z = 2.58
    radius = 1.98
    for index, degrees in enumerate(range(8, 173, 10)):
        theta = math.radians(degrees)
        x = math.cos(theta) * radius
        z = center_z + math.sin(theta) * radius
        rotation_y = math.pi * 0.5 - theta
        mat = stone if index % 3 != 1 else stone_dark
        add_box(
            f"Arch_Voussoir_{index:02d}",
            (0.46, 1.06, 0.62),
            (x, 0.0, z),
            mat,
            rotation=(0.0, rotation_y, 0.0),
            parent=root,
        )

    for index, degrees in enumerate(range(18, 163, 16)):
        theta = math.radians(degrees)
        x = math.cos(theta) * 1.55
        z = center_z + math.sin(theta) * 1.55
        rotation_y = math.pi * 0.5 - theta
        add_box(
            f"Inner_Arch_Rune_{index:02d}",
            (0.04, 0.035, 0.30),
            (x, -0.62, z),
            rune,
            rotation=(0.0, rotation_y, 0.0),
            parent=root,
        )


def build_topwork(root: bpy.types.Object, stone: bpy.types.Material, stone_dark: bpy.types.Material, rune: bpy.types.Material) -> None:
    for index, x in enumerate((-2.55, -1.65, -0.75, 0.15, 1.05, 1.95, 2.65)):
        add_box(f"Top_Fragment_Block_{index}", (0.9, 1.02, 0.42), (x, 0.0, 4.16), stone if index % 2 else stone_dark, parent=root)
    add_box("Top_Back_Wall", (4.8, 0.82, 0.55), (0.0, 0.18, 4.56), stone_dark, parent=root)
    add_box("Top_Carved_Band", (4.35, 0.09, 0.18), (0.0, -0.55, 4.54), stone, parent=root)

    add_xz_prism(
        "Central_Ruined_Crown",
        [(-0.55, 0.0), (0.55, 0.0), (0.0, 0.82)],
        0.82,
        (0.0, 0.0, 4.82),
        stone_dark,
        root,
    )
    add_cylinder("Central_Stone_Disc", 0.43, 0.08, (0.0, -0.58, 4.56), stone, vertices=14, rotation=(math.pi * 0.5, 0.0, 0.0), parent=root)
    add_torus("Central_Rune_Ring", 0.34, 0.025, (0.0, -0.635, 4.56), rune, root)
    add_box("Central_Rune_Stem", (0.055, 0.035, 0.52), (0.0, -0.665, 4.56), rune, parent=root)
    add_box("Central_Rune_Cross", (0.33, 0.035, 0.045), (0.0, -0.668, 4.61), rune, rotation=(0.0, 0.0, 0.18), parent=root)
    add_box("Central_Rune_Diamond_A", (0.055, 0.035, 0.25), (-0.08, -0.67, 4.42), rune, rotation=(0.0, -0.75, 0.0), parent=root)
    add_box("Central_Rune_Diamond_B", (0.055, 0.035, 0.25), (0.08, -0.67, 4.42), rune, rotation=(0.0, 0.75, 0.0), parent=root)

    for side in (-1, 1):
        add_box(f"{'Right' if side > 0 else 'Left'}_Crown_Shard", (0.62, 0.82, 0.72), (side * 2.65, 0.02, 4.78), stone_dark, rotation=(0.0, side * 0.08, 0.0), parent=root)
        add_xz_prism(
            f"{'Right' if side > 0 else 'Left'}_Crown_Tip",
            [(-0.34, 0.0), (0.34, 0.0), (0.02 * side, 0.58)],
            0.76,
            (side * 2.65, 0.0, 5.12),
            stone,
            root,
        )


def build_steps(root: bpy.types.Object, stone: bpy.types.Material, stone_dark: bpy.types.Material, moss: bpy.types.Material) -> None:
    for index in range(4):
        width = 5.9 - index * 0.65
        depth = 0.58
        z = 0.07 + index * 0.12
        y = -1.95 + index * 0.48
        add_box(f"Front_Step_{index}", (width, depth, 0.14), (0.0, y, z), stone if index % 2 else stone_dark, parent=root)

    for index, x in enumerate((-2.7, -1.2, 0.8, 2.2)):
        add_box(f"Step_Moss_{index}", (0.45, 0.05, 0.05), (x, -1.82 + index * 0.32, 0.23 + index * 0.03), moss, parent=root)


def build_vines(root: bpy.types.Object, vine: bpy.types.Material, moss: bpy.types.Material) -> None:
    vine_specs = [
        [(-2.85, -0.64, 4.25), (-2.95, -0.66, 3.4), (-2.72, -0.65, 2.65), (-2.82, -0.66, 1.65)],
        [(2.85, -0.64, 4.3), (2.7, -0.66, 3.45), (2.95, -0.65, 2.55), (2.82, -0.66, 1.35)],
        [(-0.45, -0.66, 4.15), (-0.35, -0.67, 3.45), (-0.18, -0.68, 2.98)],
        [(0.55, -0.66, 4.05), (0.45, -0.67, 3.35), (0.62, -0.68, 2.85)],
    ]

    for vine_index, points in enumerate(vine_specs):
        for segment_index in range(len(points) - 1):
            add_cylinder_between(
                f"Vine_{vine_index}_{segment_index}",
                points[segment_index],
                points[segment_index + 1],
                0.024,
                vine,
                root,
            )

    for index, (x, y, z) in enumerate([
        (-2.78, -0.69, 3.1),
        (-2.9, -0.69, 2.25),
        (2.74, -0.69, 3.2),
        (2.9, -0.69, 2.0),
        (0.48, -0.69, 3.15),
        (-0.31, -0.69, 3.25),
    ]):
        add_box(f"Vine_Leaf_{index}", (0.16, 0.025, 0.08), (x, y, z), moss, rotation=(0.0, 0.3 * (-1 if index % 2 else 1), 0.4), parent=root)


def build_arch() -> bpy.types.Object:
    stone = make_material("LowPoly_Chipped_Stone", (0.43, 0.42, 0.37, 1.0))
    stone_dark = make_material("LowPoly_Dark_Stone", (0.25, 0.25, 0.22, 1.0))
    moss = make_material("LowPoly_Moss", (0.18, 0.36, 0.12, 1.0))
    vine = make_material("LowPoly_Vine", (0.12, 0.26, 0.08, 1.0))
    rune = make_material("Arcane_Blue_Runes", (0.05, 0.78, 1.0, 1.0), roughness=0.38, emission=(0.0, 0.74, 1.0, 1.0), emission_strength=1.8)

    root = bpy.data.objects.new("LowPolyRuinArch", None)
    bpy.context.scene.collection.objects.link(root)

    build_steps(root, stone, stone_dark, moss)
    for side in (-1, 1):
        build_pillar(root, side, stone, stone_dark, moss, rune)
    build_arch_ring(root, stone, stone_dark, rune)
    build_topwork(root, stone, stone_dark, rune)
    build_vines(root, vine, moss)

    root["elderforge_note"] = "Low-poly ruin arch placeholder. Edit source/low_poly_ruin_arch.blend and re-export models/low_poly_ruin_arch.glb."
    return root


def main() -> None:
    args = parse_args()
    if BLEND_PATH.exists() and not args.force:
        print(f"{BLEND_PATH} already exists.")
        print("Pass -- --force to rebuild the scripted placeholder and overwrite it.")
        raise SystemExit(1)

    ASSET_ROOT.joinpath("source").mkdir(parents=True, exist_ok=True)
    ASSET_ROOT.joinpath("models").mkdir(parents=True, exist_ok=True)
    clear_scene()
    root = build_arch()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_hierarchy(root, EXPORT_PATH)
    print(f"Created {BLEND_PATH}")
    print(f"Exported {EXPORT_PATH}")


if __name__ == "__main__":
    main()
