"""Retarget one Mixamo FBX action onto Elderforge's Quaternius humanoid rig.

Run with Blender, for example:

    blender --background --python tools/animation/retarget_mixamo_to_elderforge.py -- \
        --source "C:/Users/Larry/Downloads/Sword And Shield Slash.fbx" \
        --target-rig "assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf" \
        --output assets/animations/abilities/one_handed_sword/sword_and_shield_slash.glb \
        --animation-name Sword_Whirling_Slash

The export keeps vertical hip motion but removes horizontal root travel. Gameplay
movement remains authoritative while the resulting clip can be played directly
on Elderforge's player and mob skeletons.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


BONE_MAP = (
    ("mixamorig:Hips", "pelvis"),
    ("mixamorig:Spine", "spine_01"),
    ("mixamorig:Spine1", "spine_02"),
    ("mixamorig:Spine2", "spine_03"),
    ("mixamorig:Neck", "neck_01"),
    ("mixamorig:Head", "Head"),
    ("mixamorig:LeftShoulder", "clavicle_l"),
    ("mixamorig:LeftArm", "upperarm_l"),
    ("mixamorig:LeftForeArm", "lowerarm_l"),
    ("mixamorig:LeftHand", "hand_l"),
    ("mixamorig:LeftHandThumb1", "thumb_01_l"),
    ("mixamorig:LeftHandThumb2", "thumb_02_l"),
    ("mixamorig:LeftHandThumb3", "thumb_03_l"),
    ("mixamorig:LeftHandIndex1", "index_01_l"),
    ("mixamorig:LeftHandIndex2", "index_02_l"),
    ("mixamorig:LeftHandIndex3", "index_03_l"),
    ("mixamorig:LeftHandMiddle1", "middle_01_l"),
    ("mixamorig:LeftHandMiddle2", "middle_02_l"),
    ("mixamorig:LeftHandMiddle3", "middle_03_l"),
    ("mixamorig:LeftHandRing1", "ring_01_l"),
    ("mixamorig:LeftHandRing2", "ring_02_l"),
    ("mixamorig:LeftHandRing3", "ring_03_l"),
    ("mixamorig:LeftHandPinky1", "pinky_01_l"),
    ("mixamorig:LeftHandPinky2", "pinky_02_l"),
    ("mixamorig:LeftHandPinky3", "pinky_03_l"),
    ("mixamorig:RightShoulder", "clavicle_r"),
    ("mixamorig:RightArm", "upperarm_r"),
    ("mixamorig:RightForeArm", "lowerarm_r"),
    ("mixamorig:RightHand", "hand_r"),
    ("mixamorig:RightHandThumb1", "thumb_01_r"),
    ("mixamorig:RightHandThumb2", "thumb_02_r"),
    ("mixamorig:RightHandThumb3", "thumb_03_r"),
    ("mixamorig:RightHandIndex1", "index_01_r"),
    ("mixamorig:RightHandIndex2", "index_02_r"),
    ("mixamorig:RightHandIndex3", "index_03_r"),
    ("mixamorig:RightHandMiddle1", "middle_01_r"),
    ("mixamorig:RightHandMiddle2", "middle_02_r"),
    ("mixamorig:RightHandMiddle3", "middle_03_r"),
    ("mixamorig:RightHandRing1", "ring_01_r"),
    ("mixamorig:RightHandRing2", "ring_02_r"),
    ("mixamorig:RightHandRing3", "ring_03_r"),
    ("mixamorig:RightHandPinky1", "pinky_01_r"),
    ("mixamorig:RightHandPinky2", "pinky_02_r"),
    ("mixamorig:RightHandPinky3", "pinky_03_r"),
    ("mixamorig:LeftUpLeg", "thigh_l"),
    ("mixamorig:LeftLeg", "calf_l"),
    ("mixamorig:LeftFoot", "foot_l"),
    ("mixamorig:LeftToeBase", "ball_l"),
    ("mixamorig:RightUpLeg", "thigh_r"),
    ("mixamorig:RightLeg", "calf_r"),
    ("mixamorig:RightFoot", "foot_r"),
    ("mixamorig:RightToeBase", "ball_r"),
)


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--target-rig", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--animation-name", required=True)
    return parser.parse_args(argv)


def import_gltf(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
    return [obj for obj in bpy.data.objects if obj not in before]


def import_fbx(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.wm.fbx_import(filepath=str(path.resolve()))
    return [obj for obj in bpy.data.objects if obj not in before]


def find_armature(objects: list[bpy.types.Object], required_bone: str) -> bpy.types.Object:
    for obj in objects:
        if obj.type == "ARMATURE" and required_bone in obj.data.bones:
            return obj
    raise RuntimeError(f"No imported armature contains required bone {required_bone!r}")


def world_rest_matrix(armature: bpy.types.Object, bone_name: str) -> Matrix:
    return armature.matrix_world @ armature.data.bones[bone_name].matrix_local


def world_pose_matrix(armature: bpy.types.Object, bone_name: str) -> Matrix:
    return armature.matrix_world @ armature.pose.bones[bone_name].matrix


def leg_scale(source: bpy.types.Object, target: bpy.types.Object) -> float:
    source_hip = world_rest_matrix(source, "mixamorig:Hips").translation
    source_feet = (
        world_rest_matrix(source, "mixamorig:LeftFoot").translation
        + world_rest_matrix(source, "mixamorig:RightFoot").translation
    ) * 0.5
    target_hip = world_rest_matrix(target, "pelvis").translation
    target_feet = (
        world_rest_matrix(target, "foot_l").translation
        + world_rest_matrix(target, "foot_r").translation
    ) * 0.5
    source_height = max(abs(source_hip.z - source_feet.z), 0.001)
    target_height = max(abs(target_hip.z - target_feet.z), 0.001)
    return target_height / source_height


def target_bone_position(
    target: bpy.types.Object,
    target_bone_name: str,
    source: bpy.types.Object,
    source_bone_name: str,
    movement_scale: float,
) -> Vector:
    target_rest = world_rest_matrix(target, target_bone_name)
    if target_bone_name == "pelvis":
        source_rest = world_rest_matrix(source, source_bone_name)
        source_pose = world_pose_matrix(source, source_bone_name)
        vertical_delta = (source_pose.translation.z - source_rest.translation.z) * movement_scale
        return target_rest.translation + Vector((0.0, 0.0, vertical_delta))

    target_bone = target.data.bones[target_bone_name]
    parent = target_bone.parent
    if parent is None:
        return target_rest.translation
    parent_rest = target.data.bones[parent.name].matrix_local
    rest_offset = (parent_rest.inverted() @ target_bone.matrix_local).translation
    parent_pose_world = world_pose_matrix(target, parent.name)
    return parent_pose_world @ rest_offset


def retarget_frame(
    source: bpy.types.Object,
    target: bpy.types.Object,
    source_frame: int,
    output_frame: int,
    movement_scale: float,
) -> None:
    bpy.context.scene.frame_set(source_frame)
    bpy.context.view_layer.update()

    for source_bone_name, target_bone_name in BONE_MAP:
        source_rest = world_rest_matrix(source, source_bone_name)
        source_pose = world_pose_matrix(source, source_bone_name)
        target_rest = world_rest_matrix(target, target_bone_name)
        world_delta = source_pose.to_quaternion() @ source_rest.to_quaternion().inverted()
        target_rotation = world_delta @ target_rest.to_quaternion()
        target_position = target_bone_position(
            target,
            target_bone_name,
            source,
            source_bone_name,
            movement_scale,
        )
        desired_world = Matrix.LocRotScale(target_position, target_rotation, Vector((1.0, 1.0, 1.0)))

        pose_bone = target.pose.bones[target_bone_name]
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.matrix = target.matrix_world.inverted() @ desired_world

    bpy.context.view_layer.update()
    for _, target_bone_name in BONE_MAP:
        pose_bone = target.pose.bones[target_bone_name]
        pose_bone.keyframe_insert(
            "rotation_quaternion", frame=output_frame, group=target_bone_name
        )
        if target_bone_name == "pelvis":
            pose_bone.keyframe_insert("location", frame=output_frame, group=target_bone_name)


def export_objects_for_armature(target: bpy.types.Object) -> list[bpy.types.Object]:
    # Runtime consumers copy only the action, so source meshes add size without value.
    return [target]


def main() -> None:
    args = parse_args()
    if not args.source.is_file():
        raise FileNotFoundError(args.source)
    if not args.target_rig.is_file():
        raise FileNotFoundError(args.target_rig)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    target_objects = import_gltf(args.target_rig)
    target = find_armature(target_objects, "pelvis")
    target_actions = list(bpy.data.actions)
    target.animation_data_create()
    target.animation_data.action = None
    for action in target_actions:
        bpy.data.actions.remove(action)

    source_objects = import_fbx(args.source)
    source = find_armature(source_objects, "mixamorig:Hips")
    source_action = source.animation_data.action if source.animation_data else None
    if source_action is None:
        raise RuntimeError("The Mixamo armature has no active animation action")

    missing_source = [source_name for source_name, _ in BONE_MAP if source_name not in source.data.bones]
    missing_target = [target_name for _, target_name in BONE_MAP if target_name not in target.data.bones]
    if missing_source or missing_target:
        raise RuntimeError(
            f"Bone mapping is incomplete. Source missing: {missing_source}; target missing: {missing_target}"
        )

    frame_start = int(round(source_action.frame_range[0]))
    frame_end = int(round(source_action.frame_range[1]))
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.frame_start = 0
    scene.frame_end = frame_end - frame_start

    output_action = bpy.data.actions.new(args.animation_name)
    target.animation_data.action = output_action
    movement_scale = leg_scale(source, target)
    for source_frame in range(frame_start, frame_end + 1):
        retarget_frame(
            source,
            target,
            source_frame,
            source_frame - frame_start,
            movement_scale,
        )

    for obj in source_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        if action != output_action:
            bpy.data.actions.remove(action)

    bpy.ops.object.select_all(action="DESELECT")
    export_objects = export_objects_for_armature(target)
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = target

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output.resolve()),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=True,
        export_anim_slide_to_zero=True,
        export_force_sampling=False,
        export_def_bones=True,
        export_leaf_bone=False,
        export_extra_animations=False,
        export_materials="NONE",
    )
    print(
        f"Retargeted {args.source.name} frames {frame_start}-{frame_end} "
        f"to {args.output} as {args.animation_name}"
    )


if __name__ == "__main__":
    main()
