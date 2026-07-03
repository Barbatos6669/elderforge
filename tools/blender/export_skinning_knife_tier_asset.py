"""Export one edited skinning knife tier .blend to its matching runtime GLB.

Examples:

    blender --background assets/equipment/tools/skinning_knives/t4/source/t4_skinning_knife.blend --python tools/blender/export_skinning_knife_tier_asset.py

    blender --background assets/equipment/tools/skinning_knives/t4/source/t4_skinning_knife.blend --python tools/blender/export_skinning_knife_tier_asset.py -- --tier 4
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SKINNING_KNIFE_ROOT = PROJECT_ROOT / "assets" / "equipment" / "tools" / "skinning_knives"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tier", type=int, choices=range(1, 9), help="Tier number to export.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in __import__("sys").argv:
        return []
    return __import__("sys").argv[__import__("sys").argv.index("--") + 1 :]


def infer_tier() -> int:
    blend_path = Path(bpy.data.filepath)
    match = re.search(r"t([1-8])_skinning_knife\.blend$", blend_path.name)
    if match:
        return int(match.group(1))

    for part in blend_path.parts:
        if re.fullmatch(r"t[1-8]", part):
            return int(part[1:])

    raise RuntimeError("Could not infer skinning knife tier. Pass -- --tier N.")


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def main() -> None:
    args = parse_args()
    tier = args.tier or infer_tier()
    root = bpy.data.objects.get(f"T{tier}SkinningKnife")
    if root is None:
        raise RuntimeError(f"Could not find Blender object 'T{tier}SkinningKnife'.")

    export_path = SKINNING_KNIFE_ROOT / f"t{tier}" / "models" / f"t{tier}_skinning_knife.glb"
    export_path.parent.mkdir(parents=True, exist_ok=True)

    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exported {export_path}")


if __name__ == "__main__":
    main()
