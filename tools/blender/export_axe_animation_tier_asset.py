"""Export one edited axe animation source .blend to its matching runtime GLB.

Example:

    & 'C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe' --background assets/equipment/tools/axes/t4/animations/source/t4_axe_animations.blend --python tools/blender/export_axe_animation_tier_asset.py
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
AXE_ROOT = PROJECT_ROOT / "assets" / "equipment" / "tools" / "axes"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tier", type=int, choices=range(1, 9), help="Tier number to export.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def infer_tier() -> int:
    blend_path = Path(bpy.data.filepath)
    match = re.search(r"t([1-8])_axe_animations\.blend$", blend_path.name)
    if match:
        return int(match.group(1))

    for part in blend_path.parts:
        if re.fullmatch(r"t[1-8]", part):
            return int(part[1:])

    raise RuntimeError("Could not infer axe animation tier. Pass -- --tier N.")


def main() -> None:
    args = parse_args()
    tier = args.tier or infer_tier()
    export_path = AXE_ROOT / f"t{tier}" / "animations" / "exports" / f"t{tier}_axe_animations.glb"
    export_path.parent.mkdir(parents=True, exist_ok=True)

    _select_export_objects()
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_animations=True,
    )
    print(f"Exported {export_path}")


def _select_export_objects() -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for object_name in ("Armature", "Mannequin"):
        obj = bpy.data.objects.get(object_name)
        if obj is not None:
            obj.select_set(True)
            if object_name == "Armature":
                bpy.context.view_layer.objects.active = obj


if __name__ == "__main__":
    main()
