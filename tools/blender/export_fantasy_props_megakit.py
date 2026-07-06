r"""Export edited Fantasy Props MegaKit Blend sources to runtime glTF models.

Examples:

    & 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_fantasy_props_megakit.py -- --asset anvil

    & 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/export_fantasy_props_megakit.py -- --all
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PACK_ROOT = PROJECT_ROOT / "assets" / "models" / "props" / "fantasy_props_megakit"
SOURCE_ROOT = PACK_ROOT / "source"
MODELS_ROOT = PACK_ROOT / "models"
TEXTURES_ROOT = PACK_ROOT / "textures"
IMAGE_NAME_PATTERN = re.compile(r"(.+\.(?:png|jpg|jpeg|tga|bmp|webp))(?:\.\d+)?$", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", default="", help="Asset id to export, such as anvil.")
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

    raise RuntimeError("Pass --asset, pass --all, or run this script from an opened fantasy prop source Blend.")


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


def clean_image_name(image_name: str) -> str:
    match = IMAGE_NAME_PATTERN.match(image_name)
    return match.group(1) if match else Path(image_name).name


def remap_images_to_shared_textures() -> None:
    for image in bpy.data.images:
        image_name = clean_image_name(image.name)
        texture_path = _find_texture(image_name)
        if texture_path is None:
            print(f"Warning: could not find texture for image '{image.name}'.")
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
