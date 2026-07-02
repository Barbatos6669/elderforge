"""Create the editable T1 tree source asset and Godot runtime exports.

Run with Blender:

    blender --background --python tools/blender/create_t1_tree_asset.py

The .blend file is the artist-owned source. The .glb files are the runtime
exports referenced by the Godot resource scene.
"""

from __future__ import annotations

from pathlib import Path
import sys

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "resources" / "trees"
BLEND_PATH = ASSET_DIR / "t1_tree.blend"
TRUNK_EXPORT_PATH = ASSET_DIR / "t1_tree_trunk.glb"
LEAVES_EXPORT_PATH = ASSET_DIR / "t1_tree_leaves.glb"
STUMP_EXPORT_PATH = ASSET_DIR / "t1_tree_stump.glb"


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
        shader.inputs["Roughness"].default_value = 0.9

    return material


def set_flat_shading(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return

    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def add_cone_mesh(
    name: str,
    radius_bottom: float,
    radius_top: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    vertices: int = 7,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        end_fill_type="TRIFAN",
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def add_leaf_cluster(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=8,
        ring_count=4,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    obj.data.materials.append(material)
    set_flat_shading(obj)
    return obj


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def link_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source_collection in list(obj.users_collection):
        source_collection.objects.unlink(obj)
    collection.objects.link(obj)


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


def build_tree() -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    bark = make_material("T1_Bark_Brown", (0.43, 0.25, 0.12, 1.0))
    bark_shadow = make_material("T1_Bark_Shadow", (0.26, 0.14, 0.07, 1.0))
    leaves = make_material("T1_Leaves_LightGray", (0.72, 0.72, 0.72, 1.0))

    full_collection = bpy.data.collections.new("T1_Tree_Full")
    stump_collection = bpy.data.collections.new("T1_Tree_Depleted")
    bpy.context.scene.collection.children.link(full_collection)
    bpy.context.scene.collection.children.link(stump_collection)

    full_root = bpy.data.objects.new("T1TreeFull", None)
    trunk_root = bpy.data.objects.new("Trunk", None)
    leaves_root = bpy.data.objects.new("Leaves", None)
    stump_root = bpy.data.objects.new("T1TreeDepleted", None)
    full_collection.objects.link(full_root)
    full_collection.objects.link(trunk_root)
    full_collection.objects.link(leaves_root)
    stump_collection.objects.link(stump_root)
    parent_keep_world(trunk_root, full_root)
    parent_keep_world(leaves_root, full_root)

    trunk = add_cone_mesh(
        "Trunk_Core",
        radius_bottom=0.30,
        radius_top=0.18,
        depth=1.85,
        location=(0.0, 0.0, 0.925),
        material=bark,
    )
    parent_keep_world(trunk, trunk_root)
    link_to_collection(trunk, full_collection)

    # Small shadow panels keep the blockout readable without merging bark pieces.
    for index, rotation in enumerate((0.0, 2.1, 4.2), start=1):
        ridge = add_cone_mesh(
            f"Trunk_Bark_Ridge_{index}",
            radius_bottom=0.305,
            radius_top=0.185,
            depth=1.80,
            location=(0.0, 0.0, 0.93),
            material=bark_shadow,
            vertices=3,
        )
        ridge.rotation_euler[2] = rotation
        ridge.scale = (0.22, 0.05, 1.0)
        parent_keep_world(ridge, trunk_root)
        link_to_collection(ridge, full_collection)

    leaf_specs = [
        ("Leaf_Center", (0.0, 0.0, 2.23), (0.78, 0.78, 0.55)),
        ("Leaf_Left", (-0.48, 0.05, 2.03), (0.58, 0.50, 0.41)),
        ("Leaf_Right", (0.50, -0.02, 2.01), (0.58, 0.50, 0.41)),
        ("Leaf_Back", (0.08, -0.52, 2.00), (0.46, 0.40, 0.34)),
        ("Leaf_Front", (-0.05, 0.50, 1.97), (0.46, 0.40, 0.34)),
    ]
    for name, location, scale in leaf_specs:
        leaf = add_leaf_cluster(name, location, scale, leaves)
        parent_keep_world(leaf, leaves_root)
        link_to_collection(leaf, full_collection)

    stump = add_cone_mesh(
        "DepletedStump",
        radius_bottom=0.42,
        radius_top=0.34,
        depth=0.22,
        location=(0.0, 0.0, 0.11),
        material=bark_shadow,
    )
    parent_keep_world(stump, stump_root)
    link_to_collection(stump, stump_collection)

    full_root["elderforge_note"] = "Editable full tree layout. Runtime exports split trunk and leaves into separate GLBs."
    trunk_root["elderforge_note"] = "Runtime trunk root. Re-export t1_tree_trunk.glb after trunk edits."
    leaves_root["elderforge_note"] = "Runtime leaves root. Re-export t1_tree_leaves.glb after canopy edits."
    stump_root["elderforge_note"] = "Runtime depleted stump root. Re-export t1_tree_stump.glb after edits."

    return trunk_root, leaves_root, stump_root


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    if BLEND_PATH.exists() and "--force" not in sys.argv:
        print(f"{BLEND_PATH} already exists.")
        print("Pass -- --force to rebuild the scripted placeholder and overwrite it.")
        raise SystemExit(1)

    clear_scene()
    trunk_root, leaves_root, stump_root = build_tree()

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_hierarchy(trunk_root, TRUNK_EXPORT_PATH)
    export_hierarchy(leaves_root, LEAVES_EXPORT_PATH)
    export_hierarchy(stump_root, STUMP_EXPORT_PATH)

    print(f"Created {BLEND_PATH}")
    print(f"Exported {TRUNK_EXPORT_PATH}")
    print(f"Exported {LEAVES_EXPORT_PATH}")
    print(f"Exported {STUMP_EXPORT_PATH}")


if __name__ == "__main__":
    main()
