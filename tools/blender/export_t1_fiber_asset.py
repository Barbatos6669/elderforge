"""Export the currently open T1 fiber .blend file to Godot runtime GLBs.

Run from the project root after editing the Blender file:

    blender --background assets/models/resources/fibers/source/t1_fiber.blend --python tools/blender/export_t1_fiber_asset.py
"""

from __future__ import annotations

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "resources" / "fibers"
FULL_EXPORT_PATH = ASSET_DIR / "t1_fiber_full.glb"
DEPLETED_EXPORT_PATH = ASSET_DIR / "t1_fiber_depleted.glb"


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_hierarchy(root_name: str, path: Path) -> None:
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError(f"Could not find Blender object '{root_name}'.")

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


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    export_hierarchy("T1FiberFull", FULL_EXPORT_PATH)
    export_hierarchy("T1FiberDepleted", DEPLETED_EXPORT_PATH)
    print(f"Exported {FULL_EXPORT_PATH}")
    print(f"Exported {DEPLETED_EXPORT_PATH}")


if __name__ == "__main__":
    main()
