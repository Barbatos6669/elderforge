"""Create a Blender scene with the player character as a scale reference.

Run from the project root:

    blender --background --python tools/blender/create_character_scale_reference.py -- --force

The generated .blend is not runtime art. It is an editing aid for sizing props,
buildings, doors, stairs, tools, and other hand-authored models against the
current player character.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CHARACTER_MODEL = PROJECT_ROOT / "assets" / "characters" / "base" / "Superhero_Male_FullBody.gltf"
REFERENCE_ROOT = PROJECT_ROOT / "assets" / "models" / "reference" / "character_scale"
SOURCE_DIR = REFERENCE_ROOT / "source"
BLEND_PATH = SOURCE_DIR / "character_scale_reference.blend"


def script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite the existing reference .blend.")
    return parser.parse_args(script_args())


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    for collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.collections,
        bpy.data.images,
        bpy.data.curves,
        bpy.data.armatures,
    ):
        for datablock in list(collection):
            collection.remove(datablock)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.9,
    alpha: float = 1.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Alpha"].default_value = alpha
        shader.inputs["Roughness"].default_value = roughness

    if alpha < 1.0:
        material.blend_method = "BLEND"
        material.show_transparent_back = True

    return material


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def imported_objects_since(before: set[str]) -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.name not in before]


def remove_import_only_helpers(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    kept: list[bpy.types.Object] = []
    for obj in objects:
        # The current base GLTF contains an unparented Icosphere that is not part
        # of the visible in-game character. Leaving it in makes the reference
        # scene look like the player is inside a huge ball, so strip it here.
        if obj.type == "MESH" and obj.parent is None and obj.name.lower().startswith("icosphere"):
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        kept.append(obj)
    return kept


def mesh_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_corner = Vector((float("inf"), float("inf"), float("inf")))
    max_corner = Vector((float("-inf"), float("-inf"), float("-inf")))

    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_corner.x = min(min_corner.x, world.x)
            min_corner.y = min(min_corner.y, world.y)
            min_corner.z = min(min_corner.z, world.z)
            max_corner.x = max(max_corner.x, world.x)
            max_corner.y = max(max_corner.y, world.y)
            max_corner.z = max(max_corner.z, world.z)

    return min_corner, max_corner


def set_flat_shading(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def add_line(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    material: bpy.types.Material,
    bevel_depth: float = 0.006,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(f"{name}_Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = bevel_depth
    curve.bevel_resolution = 0

    spline = curve.splines.new("POLY")
    spline.points.add(1)
    spline.points[0].co = (*start, 1.0)
    spline.points[1].co = (*end, 1.0)

    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def add_text(
    name: str,
    text: str,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    size: float = 0.12,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(f"{name}_Curve", "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size

    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    obj.rotation_euler = (1.13446, 0.0, 0.0)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def add_box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_capsule_reference(material: bpy.types.Material) -> bpy.types.Object:
    root = bpy.data.objects.new("Player_Collision_Capsule_1p8m_R0p35", None)
    bpy.context.scene.collection.objects.link(root)

    cylinder_height = 1.8 - (0.35 * 2.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.35, depth=cylinder_height, location=(0.0, 0.0, 0.9))
    cylinder = bpy.context.object
    cylinder.name = "Capsule_Cylinder"
    cylinder.data.materials.append(material)
    parent_keep_world(cylinder, root)

    for name, z in (("Capsule_Bottom", 0.35), ("Capsule_Top", 1.45)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.35, location=(0.0, 0.0, z))
        cap = bpy.context.object
        cap.name = name
        cap.data.materials.append(material)
        parent_keep_world(cap, root)

    root.display_type = "WIRE"
    return root


def add_scale_helpers() -> None:
    grid_material = make_material("Reference_Grid_Gray", (0.35, 0.38, 0.38, 1.0))
    x_axis_material = make_material("Reference_X_Red", (0.85, 0.15, 0.12, 1.0))
    y_axis_material = make_material("Reference_Y_Green", (0.18, 0.65, 0.25, 1.0))
    z_axis_material = make_material("Reference_Z_Blue", (0.1, 0.36, 0.9, 1.0))
    label_material = make_material("Reference_Label_White", (0.95, 0.95, 0.9, 1.0))
    cube_material = make_material("Reference_OneMeter_Cube", (0.25, 0.55, 1.0, 0.22), alpha=0.22)
    capsule_material = make_material("Reference_Player_Capsule", (0.15, 0.85, 1.0, 0.18), alpha=0.18)

    for index in range(-5, 6):
        material_x = y_axis_material if index == 0 else grid_material
        material_y = x_axis_material if index == 0 else grid_material
        add_line(f"Grid_X_{index:+d}", (-5.0, index, 0.0), (5.0, index, 0.0), material_x)
        add_line(f"Grid_Y_{index:+d}", (index, -5.0, 0.0), (index, 5.0, 0.0), material_y)

    add_line("Height_1m_Guide", (1.25, -0.6, 0.0), (1.25, -0.6, 1.0), z_axis_material, 0.012)
    add_line("Height_1p8m_Guide", (1.45, -0.6, 0.0), (1.45, -0.6, 1.8), z_axis_material, 0.012)
    add_line("Height_1p8m_Top", (-0.55, -0.6, 1.8), (1.65, -0.6, 1.8), z_axis_material, 0.01)

    add_box("One_Meter_Cube", (1.0, 1.0, 1.0), (-1.35, -0.7, 0.5), cube_material)
    add_capsule_reference(capsule_material)

    add_text("Label_1m", "1m", (1.25, -0.72, 1.0), label_material)
    add_text("Label_PlayerHeight", "Player collider 1.8m", (0.55, -0.72, 1.9), label_material)
    add_text("Label_OneMeterCube", "1m cube", (-1.35, -1.32, 1.08), label_material)
    add_text("Label_Feet", "Feet on ground plane", (0.0, 0.95, 0.08), label_material, 0.11)


def add_camera_and_light() -> None:
    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 6.0))
    light = bpy.context.object
    light.name = "Reference_Sun"
    light.data.energy = 2.0
    light.rotation_euler = (0.785398, 0.0, 0.785398)

    bpy.ops.object.camera_add(location=(3.0, -5.0, 3.0), rotation=(1.0472, 0.0, 0.52))
    camera = bpy.context.object
    bpy.context.scene.camera = camera


def import_character() -> tuple[bpy.types.Object, Vector, Vector]:
    before = {obj.name for obj in bpy.context.scene.objects}
    bpy.ops.import_scene.gltf(filepath=str(CHARACTER_MODEL))
    imported = remove_import_only_helpers(imported_objects_since(before))

    root = bpy.data.objects.new("Player_Character_Scale_Reference", None)
    bpy.context.scene.collection.objects.link(root)

    top_level_imported = [obj for obj in imported if obj.parent is None]
    for obj in top_level_imported:
        parent_keep_world(obj, root)

    min_corner, max_corner = mesh_bounds(imported)
    center = (min_corner + max_corner) * 0.5
    root.location = Vector((-center.x, -center.y, -min_corner.z))
    bpy.context.view_layer.update()

    min_corner, max_corner = mesh_bounds(imported)
    root["elderforge_note"] = "Current player model imported from assets/characters/base/Superhero_Male_FullBody.gltf."
    root["reference_height_meters"] = round(max_corner.z - min_corner.z, 4)
    return root, min_corner, max_corner


def main() -> None:
    args = parse_args()
    if BLEND_PATH.exists() and not args.force:
        print(f"{BLEND_PATH} already exists.")
        print("Pass -- --force to rebuild the character scale reference.")
        raise SystemExit(1)

    if not CHARACTER_MODEL.exists():
        raise SystemExit(f"Missing character model: {CHARACTER_MODEL}")

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    _, min_corner, max_corner = import_character()
    add_scale_helpers()
    add_camera_and_light()

    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)

    size = max_corner - min_corner
    print(f"Created {BLEND_PATH}")
    print(f"Character bounds size: {size.x:.3f}m x {size.y:.3f}m x {size.z:.3f}m")


if __name__ == "__main__":
    main()
