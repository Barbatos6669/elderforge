"""Export the currently open T1 axe .blend file to the Godot runtime GLB.

Run from the project root after editing the Blender file:

    blender --background assets/models/equipment/axes/t1_axe.blend --python tools/blender/export_t1_axe_asset.py
"""

from __future__ import annotations

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = PROJECT_ROOT / "assets" / "models" / "equipment" / "axes"
EXPORT_PATH = ASSET_DIR / "t1_axe.glb"


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def main() -> None:
    root = bpy.data.objects.get("T1Axe")
    if root is None:
        raise RuntimeError("Could not find Blender object 'T1Axe'.")

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exported {EXPORT_PATH}")


if __name__ == "__main__":
    main()
