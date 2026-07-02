"""Create the editable T1 rock source asset and Godot runtime exports.

Run with Blender:

    blender --background --python tools/blender/create_t1_rock_asset.py -- --force

The .blend file is the artist-owned source. The .glb files are the runtime
exports referenced by the Godot resource scene.
"""

from __future__ import annotations

from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "resources" / "rocks"
BLEND_PATH = ASSET_DIR / "t1_rock.blend"
FULL_EXPORT_PATH = ASSET_DIR / "t1_rock_full.glb"
DEPLETED_EXPORT_PATH = ASSET_DIR / "t1_rock_depleted.glb"


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


def make_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = 0.95

    return material


def set_flat_shading(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return

    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def link_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source_collection in list(obj.users_collection):
        source_collection.objects.unlink(obj)
    collection.objects.link(obj)


def add_low_poly_rock(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    seed: int,
) -> bpy.types.Object:
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    obj.data.materials.append(material)

    for vertex in obj.data.vertices:
        direction = vertex.co.normalized()
        if direction.length_squared == 0.0:
            direction = Vector((0.0, 0.0, 1.0))
        vertex.co *= random.uniform(0.78, 1.16)
        vertex.co.x += random.uniform(-0.08, 0.08)
        vertex.co.y += random.uniform(-0.08, 0.08)
        vertex.co.z = max(vertex.co.z + random.uniform(-0.1, 0.12), -0.78)

    set_flat_shading(obj)
    return obj


def add_chip(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    seed: int,
) -> bpy.types.Object:
    obj = add_low_poly_rock(name, location, scale, material, seed)
    obj.rotation_euler[2] = random.uniform(-0.7, 0.7)
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


def build_rock() -> tuple[bpy.types.Object, bpy.types.Object]:
    stone = make_material("T1_Stone_LightGray", (0.58, 0.58, 0.56, 1.0))
    stone_dark = make_material("T1_Stone_Dark", (0.34, 0.34, 0.33, 1.0))

    full_collection = bpy.data.collections.new("T1_Rock_Full")
    depleted_collection = bpy.data.collections.new("T1_Rock_Depleted")
    bpy.context.scene.collection.children.link(full_collection)
    bpy.context.scene.collection.children.link(depleted_collection)

    full_root = bpy.data.objects.new("T1RockFull", None)
    depleted_root = bpy.data.objects.new("T1RockDepleted", None)
    full_collection.objects.link(full_root)
    depleted_collection.objects.link(depleted_root)

    full_specs = [
        ("CenterRock", (0.0, 0.0, 0.47), (0.66, 0.50, 0.45), stone, 11),
        ("LeftRock", (-0.42, 0.16, 0.30), (0.38, 0.30, 0.28), stone_dark, 12),
        ("RightRock", (0.42, -0.12, 0.28), (0.34, 0.28, 0.26), stone, 13),
    ]
    for name, location, scale, material, seed in full_specs:
        rock = add_low_poly_rock(name, location, scale, material, seed)
        parent_keep_world(rock, full_root)
        link_to_collection(rock, full_collection)

    depleted_specs = [
        ("RubbleCenter", (0.0, 0.0, 0.12), (0.32, 0.24, 0.12), stone_dark, 31),
        ("RubbleLeft", (-0.34, 0.13, 0.08), (0.18, 0.14, 0.08), stone, 32),
        ("RubbleRight", (0.34, -0.1, 0.08), (0.16, 0.12, 0.07), stone, 33),
        ("RubbleFront", (0.06, 0.34, 0.06), (0.14, 0.1, 0.06), stone_dark, 34),
    ]
    for name, location, scale, material, seed in depleted_specs:
        chip = add_chip(name, location, scale, material, seed)
        parent_keep_world(chip, depleted_root)
        link_to_collection(chip, depleted_collection)

    full_root["elderforge_note"] = "Runtime full T1 rock root. Re-export t1_rock_full.glb after edits."
    depleted_root["elderforge_note"] = "Runtime depleted T1 rock root. Re-export t1_rock_depleted.glb after edits."

    return full_root, depleted_root


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    if BLEND_PATH.exists() and "--force" not in sys.argv:
        print(f"{BLEND_PATH} already exists.")
        print("Pass -- --force to rebuild the scripted placeholder and overwrite it.")
        raise SystemExit(1)

    clear_scene()
    full_root, depleted_root = build_rock()

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_hierarchy(full_root, FULL_EXPORT_PATH)
    export_hierarchy(depleted_root, DEPLETED_EXPORT_PATH)

    print(f"Created {BLEND_PATH}")
    print(f"Exported {FULL_EXPORT_PATH}")
    print(f"Exported {DEPLETED_EXPORT_PATH}")


if __name__ == "__main__":
    main()
