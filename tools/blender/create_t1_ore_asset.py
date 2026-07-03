"""Create the editable T1 ore source asset and Godot runtime exports.

Run with Blender:

    blender --background --python tools/blender/create_t1_ore_asset.py -- --force

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
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "resources" / "ores"
SOURCE_DIR = ASSET_DIR / "source"
BLEND_PATH = SOURCE_DIR / "t1_ore.blend"
FULL_EXPORT_PATH = ASSET_DIR / "t1_ore_full.glb"
DEPLETED_EXPORT_PATH = ASSET_DIR / "t1_ore_depleted.glb"


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
    roughness: float = 0.9,
    metallic: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic

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
        vertex.co *= random.uniform(0.72, 1.18)
        vertex.co.x += random.uniform(-0.09, 0.09)
        vertex.co.y += random.uniform(-0.09, 0.09)
        vertex.co.z = max(vertex.co.z + random.uniform(-0.08, 0.14), -0.72)

    set_flat_shading(obj)
    return obj


def add_crystal_shard(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=6,
        radius1=radius,
        radius2=radius * 0.34,
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


def add_ore_plate(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    obj.data.materials.append(material)
    set_flat_shading(obj)
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


def build_ore() -> tuple[bpy.types.Object, bpy.types.Object]:
    host_dark = make_material("T1_Ore_HostRock_Dark", (0.25, 0.26, 0.26, 1.0))
    host_mid = make_material("T1_Ore_HostRock_Mid", (0.38, 0.39, 0.38, 1.0))
    ore = make_material("T1_Ore_LightGray_Metal", (0.72, 0.72, 0.72, 1.0), 0.58, 0.35)
    ore_bright = make_material("T1_Ore_BrightFacet", (0.92, 0.94, 0.96, 1.0), 0.42, 0.45)

    full_collection = bpy.data.collections.new("T1_Ore_Full")
    depleted_collection = bpy.data.collections.new("T1_Ore_Depleted")
    bpy.context.scene.collection.children.link(full_collection)
    bpy.context.scene.collection.children.link(depleted_collection)

    full_root = bpy.data.objects.new("T1OreFull", None)
    depleted_root = bpy.data.objects.new("T1OreDepleted", None)
    full_collection.objects.link(full_root)
    depleted_collection.objects.link(depleted_root)

    full_specs = [
        ("OreHostCenter", (0.0, 0.0, 0.44), (0.62, 0.50, 0.42), host_dark, 51),
        ("OreHostLeft", (-0.4, 0.18, 0.28), (0.34, 0.28, 0.24), host_mid, 52),
        ("OreHostRight", (0.42, -0.16, 0.25), (0.32, 0.27, 0.23), host_dark, 53),
    ]
    for name, location, scale, material, seed in full_specs:
        rock = add_low_poly_rock(name, location, scale, material, seed)
        parent_keep_world(rock, full_root)
        link_to_collection(rock, full_collection)

    full_ore_parts = [
        add_crystal_shard("CenterOreShard", (0.03, -0.04, 0.9), 0.13, 0.58, ore_bright, (0.18, -0.28, 0.2)),
        add_crystal_shard("LeftOreShard", (-0.25, 0.12, 0.67), 0.09, 0.36, ore, (-0.34, 0.16, -0.35)),
        add_crystal_shard("RightOreShard", (0.32, -0.08, 0.64), 0.08, 0.32, ore, (0.22, 0.36, 0.45)),
        add_ore_plate("FrontOreVein", (-0.05, -0.43, 0.38), (0.33, 0.025, 0.06), ore_bright, (0.0, 0.0, 0.35)),
        add_ore_plate("LeftOreVein", (-0.36, -0.12, 0.35), (0.22, 0.023, 0.045), ore, (0.0, 0.16, -0.5)),
    ]
    for part in full_ore_parts:
        parent_keep_world(part, full_root)
        link_to_collection(part, full_collection)

    depleted_specs = [
        ("OreRubbleCenter", (0.0, 0.0, 0.11), (0.28, 0.22, 0.10), host_dark, 71),
        ("OreRubbleLeft", (-0.31, 0.14, 0.08), (0.16, 0.12, 0.07), host_mid, 72),
        ("OreRubbleRight", (0.31, -0.11, 0.08), (0.16, 0.12, 0.07), host_dark, 73),
        ("OreChip", (0.08, 0.33, 0.06), (0.11, 0.08, 0.045), ore, 74),
    ]
    for name, location, scale, material, seed in depleted_specs:
        rubble = add_low_poly_rock(name, location, scale, material, seed)
        parent_keep_world(rubble, depleted_root)
        link_to_collection(rubble, depleted_collection)

    depleted_ore_part = add_crystal_shard("SpentOreShard", (0.18, -0.1, 0.19), 0.045, 0.15, ore, (0.2, 0.4, 0.1))
    parent_keep_world(depleted_ore_part, depleted_root)
    link_to_collection(depleted_ore_part, depleted_collection)

    full_root["elderforge_note"] = "Runtime full T1 ore root. Re-export t1_ore_full.glb after edits."
    depleted_root["elderforge_note"] = "Runtime depleted T1 ore root. Re-export t1_ore_depleted.glb after edits."

    return full_root, depleted_root


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    (SOURCE_DIR / ".gdignore").write_text(
        "Godot uses the exported GLBs in ../; edit this source in Blender 5.1.\n",
        encoding="utf-8",
    )
    if BLEND_PATH.exists() and "--force" not in sys.argv:
        print(f"{BLEND_PATH} already exists.")
        print("Pass -- --force to rebuild the scripted placeholder and overwrite it.")
        raise SystemExit(1)

    clear_scene()
    full_root, depleted_root = build_ore()

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_hierarchy(full_root, FULL_EXPORT_PATH)
    export_hierarchy(depleted_root, DEPLETED_EXPORT_PATH)

    print(f"Created {BLEND_PATH}")
    print(f"Exported {FULL_EXPORT_PATH}")
    print(f"Exported {DEPLETED_EXPORT_PATH}")


if __name__ == "__main__":
    main()
