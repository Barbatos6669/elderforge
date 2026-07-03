"""Create the editable T1 fiber source asset and Godot runtime exports.

Run with Blender:

    blender --background --python tools/blender/create_t1_fiber_asset.py -- --force

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
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "resources" / "fibers"
SOURCE_DIR = ASSET_DIR / "source"
BLEND_PATH = SOURCE_DIR / "t1_fiber.blend"
FULL_EXPORT_PATH = ASSET_DIR / "t1_fiber_full.glb"
DEPLETED_EXPORT_PATH = ASSET_DIR / "t1_fiber_depleted.glb"


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
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
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


def link_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source_collection in list(obj.users_collection):
        source_collection.objects.unlink(obj)
    collection.objects.link(obj)


def add_stem(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
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


def add_leaf(
    name: str,
    center: tuple[float, float, float],
    length: float,
    width: float,
    material: bpy.types.Material,
    rotation_z: float,
    tilt: float,
) -> bpy.types.Object:
    half_width = width * 0.5
    vertices = [
        Vector((0.0, 0.0, length * 0.55)),
        Vector((-half_width, 0.0, 0.0)),
        Vector((0.0, 0.0, -length * 0.45)),
        Vector((half_width, 0.0, 0.0)),
    ]
    faces = [(0, 1, 2, 3)]

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = center
    obj.rotation_euler = (tilt, 0.0, rotation_z)
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_cotton_boll(
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
        vertex.co *= random.uniform(0.82, 1.18)
        vertex.co.x += random.uniform(-0.05, 0.05)
        vertex.co.y += random.uniform(-0.05, 0.05)
        vertex.co.z += random.uniform(-0.04, 0.06)

    set_flat_shading(obj)
    return obj


def add_capsule_husk(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float],
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=5,
        radius1=radius,
        radius2=radius * 0.22,
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


def build_fiber() -> tuple[bpy.types.Object, bpy.types.Object]:
    stem = make_material("T1_Fiber_Stem", (0.36, 0.24, 0.10, 1.0))
    leaf = make_material("T1_Fiber_Leaf", (0.32, 0.50, 0.25, 1.0))
    leaf_dark = make_material("T1_Fiber_Leaf_Dark", (0.20, 0.34, 0.18, 1.0))
    cotton = make_material("T1_Fiber_Cotton_LightGray", (0.86, 0.84, 0.78, 1.0), 0.98)
    husk = make_material("T1_Fiber_DryHusk", (0.55, 0.32, 0.14, 1.0))

    full_collection = bpy.data.collections.new("T1_Fiber_Full")
    depleted_collection = bpy.data.collections.new("T1_Fiber_Depleted")
    bpy.context.scene.collection.children.link(full_collection)
    bpy.context.scene.collection.children.link(depleted_collection)

    full_root = bpy.data.objects.new("T1FiberFull", None)
    depleted_root = bpy.data.objects.new("T1FiberDepleted", None)
    full_collection.objects.link(full_root)
    depleted_collection.objects.link(depleted_root)

    stems = [
        add_stem("CenterStem", (0.0, 0.0, 0.46), 0.035, 0.92, stem, (0.08, 0.0, 0.0)),
        add_stem("LeftStem", (-0.22, 0.08, 0.39), 0.026, 0.74, stem, (0.2, -0.18, -0.18)),
        add_stem("RightStem", (0.22, -0.06, 0.37), 0.026, 0.72, stem, (-0.16, 0.2, 0.22)),
    ]
    for part in stems:
        parent_keep_world(part, full_root)
        link_to_collection(part, full_collection)

    leaves = [
        add_leaf("FrontLeaf", (0.0, -0.28, 0.32), 0.48, 0.26, leaf, 0.0, 1.25),
        add_leaf("BackLeaf", (0.02, 0.28, 0.34), 0.42, 0.22, leaf_dark, 3.14, 1.18),
        add_leaf("LeftLeaf", (-0.28, 0.02, 0.44), 0.40, 0.22, leaf, -1.35, 1.15),
        add_leaf("RightLeaf", (0.28, -0.02, 0.43), 0.40, 0.22, leaf_dark, 1.35, 1.15),
        add_leaf("LowLeaf", (-0.06, -0.16, 0.2), 0.32, 0.18, leaf_dark, -0.35, 1.22),
    ]
    for part in leaves:
        parent_keep_world(part, full_root)
        link_to_collection(part, full_collection)

    bolls = [
        add_cotton_boll("CenterCottonBoll", (0.02, 0.0, 0.93), (0.18, 0.16, 0.15), cotton, 101),
        add_cotton_boll("LeftCottonBoll", (-0.24, 0.08, 0.74), (0.14, 0.12, 0.12), cotton, 102),
        add_cotton_boll("RightCottonBoll", (0.25, -0.08, 0.71), (0.13, 0.12, 0.11), cotton, 103),
    ]
    for part in bolls:
        parent_keep_world(part, full_root)
        link_to_collection(part, full_collection)

    husks = [
        add_capsule_husk("CenterHusk", (0.02, 0.0, 0.77), 0.09, 0.18, husk, (0.0, 0.0, 0.0)),
        add_capsule_husk("LeftHusk", (-0.24, 0.08, 0.62), 0.07, 0.14, husk, (-0.2, 0.2, 0.0)),
        add_capsule_husk("RightHusk", (0.25, -0.08, 0.59), 0.065, 0.13, husk, (0.18, -0.2, 0.0)),
    ]
    for part in husks:
        parent_keep_world(part, full_root)
        link_to_collection(part, full_collection)

    depleted_parts = [
        add_stem("CutCenterStem", (0.0, 0.0, 0.19), 0.035, 0.38, stem, (0.06, 0.0, 0.0)),
        add_stem("CutLeftStem", (-0.18, 0.08, 0.15), 0.026, 0.30, stem, (0.2, -0.18, -0.18)),
        add_stem("CutRightStem", (0.18, -0.06, 0.14), 0.026, 0.28, stem, (-0.16, 0.2, 0.22)),
        add_leaf("WiltedLeafLeft", (-0.2, 0.05, 0.1), 0.28, 0.15, leaf_dark, -1.0, 1.45),
        add_leaf("WiltedLeafRight", (0.2, -0.04, 0.1), 0.26, 0.14, leaf_dark, 1.0, 1.45),
        add_cotton_boll("DroppedCottonTuft", (0.04, -0.25, 0.08), (0.08, 0.065, 0.05), cotton, 121),
    ]
    for part in depleted_parts:
        parent_keep_world(part, depleted_root)
        link_to_collection(part, depleted_collection)

    full_root["elderforge_note"] = "Runtime full T1 fiber root. Re-export t1_fiber_full.glb after edits."
    depleted_root["elderforge_note"] = "Runtime depleted T1 fiber root. Re-export t1_fiber_depleted.glb after edits."

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
    full_root, depleted_root = build_fiber()

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_hierarchy(full_root, FULL_EXPORT_PATH)
    export_hierarchy(depleted_root, DEPLETED_EXPORT_PATH)

    print(f"Created {BLEND_PATH}")
    print(f"Exported {FULL_EXPORT_PATH}")
    print(f"Exported {DEPLETED_EXPORT_PATH}")


if __name__ == "__main__":
    main()
