"""Create editable per-tier axe animation source files and runtime exports.

Run from the project root:

    & 'C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe' --background --python tools/blender/create_axe_animation_tier_sources.py

This extracts the TreeChopping source action from Universal Animation Library 2
into each axe tier's animation folder. Artists can then open the tier-local
`.blend`, edit the action, and export that tier's `.glb` again.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_BLEND = PROJECT_ROOT / "assets" / "animations" / "source" / "universal_animation_library_2" / "UAL2.blend"
AXE_ROOT = PROJECT_ROOT / "assets" / "equipment" / "tools" / "axes"
SOURCE_ACTION_NAME = "TreeChopping_Loop"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tier", type=int, choices=range(1, 9), help="Only generate one tier.")
    return parser.parse_args(_script_args())


def _script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def main() -> None:
    args = parse_args()
    tiers = [args.tier] if args.tier else list(range(1, 9))
    for tier in tiers:
        create_tier_animation_source(tier)


def create_tier_animation_source(tier: int) -> None:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))

    target_action_name = f"T{tier}_Axe_TreeChopping"
    action = bpy.data.actions.get(SOURCE_ACTION_NAME)
    if action is None:
        raise RuntimeError(f"Could not find source action '{SOURCE_ACTION_NAME}'.")

    action.name = target_action_name
    action.use_fake_user = True
    _remove_other_actions(action)
    _assign_action_to_armature(action)

    source_dir = AXE_ROOT / f"t{tier}" / "animations" / "source"
    export_dir = AXE_ROOT / f"t{tier}" / "animations" / "exports"
    source_dir.mkdir(parents=True, exist_ok=True)
    export_dir.mkdir(parents=True, exist_ok=True)

    blend_path = source_dir / f"t{tier}_axe_animations.blend"
    export_path = export_dir / f"t{tier}_axe_animations.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
    _export_animation_glb(export_path)
    print(f"Created {blend_path}")
    print(f"Exported {export_path}")


def _remove_other_actions(kept_action: bpy.types.Action) -> None:
    for action in list(bpy.data.actions):
        if action != kept_action:
            bpy.data.actions.remove(action)


def _assign_action_to_armature(action: bpy.types.Action) -> None:
    armature = bpy.data.objects.get("Armature")
    if armature is None:
        raise RuntimeError("Could not find source Armature object.")

    armature.animation_data_create()
    armature.animation_data.action = action
    for track in armature.animation_data.nla_tracks:
        track.mute = True


def _export_animation_glb(export_path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for object_name in ("Armature", "Mannequin"):
        obj = bpy.data.objects.get(object_name)
        if obj is not None:
            obj.select_set(True)
            if object_name == "Armature":
                bpy.context.view_layer.objects.active = obj

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


if __name__ == "__main__":
    main()
