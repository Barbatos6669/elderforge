"""Export one edited refining/crafting station .blend to its runtime GLB.

Example:

    blender --background assets/models/refining_stations/sawmills/t4/source/t4_sawmill.blend --python tools/blender/export_refining_station_tier_asset.py
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
STATION_ROOT = PROJECT_ROOT / "assets" / "models" / "refining_stations"

FAMILIES = {
    "sawmills": ("sawmill", "Sawmill"),
    "stonecutters": ("stonecutter", "Stonecutter"),
    "smelters": ("smelter", "Smelter"),
    "looms": ("loom", "Loom"),
    "toolmakers": ("toolmaker", "Toolmaker"),
    "weapon_smiths": ("weapon_smith", "WeaponSmith"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", choices=FAMILIES.keys(), help="Station family folder.")
    parser.add_argument("--tier", type=int, choices=range(1, 9), help="Tier number to export.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in __import__("sys").argv:
        return []
    return __import__("sys").argv[__import__("sys").argv.index("--") + 1 :]


def infer_family_and_tier() -> tuple[str, int]:
    blend_path = Path(bpy.data.filepath)
    for family, (file_stem, _root_stem) in FAMILIES.items():
        match = re.search(rf"t([1-8])_{file_stem}\.blend$", blend_path.name)
        if match:
            return family, int(match.group(1))

    family = next((part for part in blend_path.parts if part in FAMILIES), "")
    tier_part = next((part for part in blend_path.parts if re.fullmatch(r"t[1-8]", part)), "")
    if family and tier_part:
        return family, int(tier_part[1:])

    raise RuntimeError("Could not infer station family/tier. Pass -- --family FAMILY --tier N.")


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def main() -> None:
    args = parse_args()
    inferred_family, inferred_tier = infer_family_and_tier()
    family = args.family or inferred_family
    tier = args.tier or inferred_tier
    file_stem, root_stem = FAMILIES[family]

    root = bpy.data.objects.get(f"T{tier}{root_stem}")
    if root is None:
        raise RuntimeError(f"Could not find Blender object 'T{tier}{root_stem}'.")

    export_path = STATION_ROOT / family / f"t{tier}" / "models" / f"t{tier}_{file_stem}.glb"
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
