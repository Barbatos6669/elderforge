r"""Export edited Free 3D Modular Game Assets Blend sources to runtime glTF.

Examples:

    & 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_modular_prototyping_assets.py -- --asset wall

    & 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_modular_prototyping_assets.py -- --all
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PACK_ROOT = PROJECT_ROOT / "assets" / "models" / "props" / "free_3d_modular_game_assets_for_prototyping"
SOURCE_ROOT = PACK_ROOT / "source"
MODELS_ROOT = PACK_ROOT / "models"
TEXTURES_ROOT = PACK_ROOT / "textures"
IMAGE_NAME_PATTERN = re.compile(r"(.+\.(?:png|jpg|jpeg|tga|bmp|webp))(?:\.\d+)?$", re.IGNORECASE)
NORMALIZATION_EPSILON = 0.0001


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", default="", help="Asset id to export, such as wall.")
    parser.add_argument("--all", action="store_true", help="Export every Blend source in the pack.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def source_files(args: argparse.Namespace) -> list[Path]:
    if args.all:
        return sorted(SOURCE_ROOT.glob("*.blend"))
    if args.asset:
        source_path = SOURCE_ROOT / f"{args.asset}.blend"
        if not source_path.exists():
            raise RuntimeError(f"Missing source Blend: {source_path}")
        return [source_path]

    current_path = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if current_path and current_path.parent == SOURCE_ROOT.resolve():
        return [current_path]

    raise RuntimeError("Pass --asset, pass --all, or run this script from an opened modular source Blend.")


def root_object(asset_id: str) -> bpy.types.Object:
    by_name = bpy.data.objects.get(asset_id)
    if by_name is not None:
        return by_name

    for obj in bpy.data.objects:
        if obj.get("elderforge_asset_id") == asset_id:
            return obj

    raise RuntimeError(f"Could not find root object for '{asset_id}'.")


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def normalize_hierarchy_to_bottom_center(root: bpy.types.Object) -> None:
    """Keep the exported prefab origin at the asset's bottom center.

    This makes Godot placement predictable: dropping a prop at world zero puts
    the visible mesh on that point instead of several meters away from it.
    """

    mesh_objects = [obj for obj in root.children_recursive if obj.type == "MESH"]
    if not mesh_objects:
        return

    min_corner = Vector((float("inf"), float("inf"), float("inf")))
    max_corner = Vector((float("-inf"), float("-inf"), float("-inf")))

    for obj in mesh_objects:
        for local_corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(local_corner)
            min_corner.x = min(min_corner.x, world_corner.x)
            min_corner.y = min(min_corner.y, world_corner.y)
            min_corner.z = min(min_corner.z, world_corner.z)
            max_corner.x = max(max_corner.x, world_corner.x)
            max_corner.y = max(max_corner.y, world_corner.y)
            max_corner.z = max(max_corner.z, world_corner.z)

    offset = Vector(
        (
            (min_corner.x + max_corner.x) * 0.5,
            (min_corner.y + max_corner.y) * 0.5,
            min_corner.z,
        )
    )
    if offset.length <= NORMALIZATION_EPSILON:
        return

    for child in root.children:
        child.matrix_world.translation -= offset

    bpy.context.view_layer.update()


def clean_image_name(image_name: str) -> str:
    match = IMAGE_NAME_PATTERN.match(image_name)
    return match.group(1) if match else Path(image_name).name


def remap_images_to_shared_textures() -> None:
    for image in bpy.data.images:
        image_name = clean_image_name(image.name)
        texture_path = _find_texture(image_name)
        if texture_path is None:
            continue

        image.filepath = str(texture_path)
        try:
            image.reload()
        except RuntimeError as error:
            print(f"Warning: could not reload texture '{texture_path}': {error}")


def _find_texture(image_name: str) -> Path | None:
    direct_path = TEXTURES_ROOT / image_name
    if direct_path.exists():
        return direct_path

    matches = list(TEXTURES_ROOT.rglob(image_name))
    return matches[0] if matches else None


def export_source(source_path: Path) -> None:
    asset_id = source_path.stem
    bpy.ops.wm.open_mainfile(filepath=str(source_path))
    remap_images_to_shared_textures()
    root = root_object(asset_id)
    normalize_hierarchy_to_bottom_center(root)
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))

    MODELS_ROOT.mkdir(parents=True, exist_ok=True)
    export_path = MODELS_ROOT / f"{asset_id}.gltf"
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLTF_SEPARATE",
        export_keep_originals=True,
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exported {export_path.relative_to(PROJECT_ROOT)}")


def main() -> None:
    args = parse_args()
    paths = source_files(args)
    if not paths:
        raise RuntimeError(f"No Blend sources found in {SOURCE_ROOT}")

    for source_path in paths:
        export_source(source_path)


if __name__ == "__main__":
    main()
