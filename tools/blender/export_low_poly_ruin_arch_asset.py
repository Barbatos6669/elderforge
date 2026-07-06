"""Export the edited low-poly ruin arch .blend to its runtime GLB.

Example:

    blender --background assets/models/props/ruin_arch/source/low_poly_ruin_arch.blend --python tools/blender/export_low_poly_ruin_arch_asset.py
"""

from __future__ import annotations

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
EXPORT_PATH = PROJECT_ROOT / "assets" / "models" / "props" / "ruin_arch" / "models" / "low_poly_ruin_arch.glb"
ROOT_OBJECT = "LowPolyRuinArch"


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def main() -> None:
    root = bpy.data.objects.get(ROOT_OBJECT)
    if root is None:
        raise RuntimeError(f"Could not find Blender object '{ROOT_OBJECT}'.")

    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
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
