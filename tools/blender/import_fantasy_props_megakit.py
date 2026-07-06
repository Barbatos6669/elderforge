r"""Convert the Fantasy Props MegaKit FBX files into editable Blend sources.

Run from the project root:

    & 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/blender/import_fantasy_props_megakit.py -- --force

The raw FBX files stay under the pack folder as third-party input. The generated
.blend files are the artist-editable sources, and the generated glTF files are
the runtime Godot models.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PACK_ROOT = PROJECT_ROOT / "assets" / "models" / "props" / "fantasy_props_megakit"
FBX_ROOT = PACK_ROOT / "FBX"
SOURCE_ROOT = PACK_ROOT / "source"
MODELS_ROOT = PACK_ROOT / "models"
TEXTURES_ROOT = PACK_ROOT / "textures"
IMAGE_NAME_PATTERN = re.compile(r"(.+\.(?:png|jpg|jpeg|tga|bmp|webp))(?:\.\d+)?$", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing Blend sources and glTF models.")
    parser.add_argument("--only", default="", help="Only convert one asset. Accepts FBX stem or generated asset id.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def asset_id_from_stem(stem: str) -> str:
    words = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?=[A-Z]|$)|\d+", stem)
    return "_".join(word.lower() for word in words)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for collection in (
        bpy.data.actions,
        bpy.data.armatures,
        bpy.data.cameras,
        bpy.data.collections,
        bpy.data.images,
        bpy.data.lights,
        bpy.data.materials,
        bpy.data.meshes,
    ):
        for datablock in list(collection):
            collection.remove(datablock)


def top_level_objects(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    imported = set(objects)
    return [obj for obj in objects if obj.parent not in imported]


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


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


def import_fbx_to_source(fbx_path: Path, asset_id: str) -> bpy.types.Object:
    clear_scene()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(fbx_path))
    imported = [obj for obj in bpy.data.objects if obj not in before]

    if not imported:
        raise RuntimeError(f"No objects were imported from {fbx_path}.")

    remap_images_to_shared_textures()

    root = bpy.data.objects.new(asset_id, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    for obj in top_level_objects(imported):
        parent_keep_world(obj, root)

    root["elderforge_asset_id"] = asset_id
    root["elderforge_source_fbx"] = fbx_path.relative_to(PROJECT_ROOT).as_posix()
    root["elderforge_note"] = (
        "Fantasy Props MegaKit converted source. Edit this .blend, then run "
        "tools/blender/export_fantasy_props_megakit.py to refresh the runtime glTF."
    )

    return root


def save_source(root: bpy.types.Object, asset_id: str) -> Path:
    source_path = SOURCE_ROOT / f"{asset_id}.blend"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    return source_path


def export_runtime_model(root: bpy.types.Object, asset_id: str) -> Path:
    export_path = MODELS_ROOT / f"{asset_id}.gltf"
    export_path.parent.mkdir(parents=True, exist_ok=True)
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
    return export_path


def matching_assets(only: str) -> list[Path]:
    fbx_paths = sorted(FBX_ROOT.glob("*.fbx"))
    if not only:
        return fbx_paths

    normalized = only.lower()
    matches = [
        path
        for path in fbx_paths
        if path.stem.lower() == normalized or asset_id_from_stem(path.stem) == normalized
    ]
    if not matches:
        raise RuntimeError(f"Could not find fantasy prop asset matching '{only}'.")
    return matches


def convert_asset(fbx_path: Path, force: bool) -> None:
    asset_id = asset_id_from_stem(fbx_path.stem)
    source_path = SOURCE_ROOT / f"{asset_id}.blend"
    export_path = MODELS_ROOT / f"{asset_id}.gltf"

    if source_path.exists() and export_path.exists() and not force:
        print(f"Skipping {asset_id}; source and model already exist.")
        return

    root = import_fbx_to_source(fbx_path, asset_id)
    saved_source = save_source(root, asset_id)
    saved_model = export_runtime_model(root, asset_id)
    print(f"Converted {fbx_path.name} -> {saved_source.relative_to(PROJECT_ROOT)}")
    print(f"Exported {saved_model.relative_to(PROJECT_ROOT)}")


def main() -> None:
    args = parse_args()
    if not FBX_ROOT.exists():
        raise RuntimeError(f"Missing FBX folder: {FBX_ROOT}")

    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    MODELS_ROOT.mkdir(parents=True, exist_ok=True)

    for fbx_path in matching_assets(args.only):
        convert_asset(fbx_path, args.force)


if __name__ == "__main__":
    main()
