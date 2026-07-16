# Equipment Animation Profiles

Equipment animation profiles let a tool or weapon choose animation behavior
without adding item-specific branches to the player controller.

`one_handed_sword_animation_profile.tres` currently provides:

- the authored `Sword_Idle` stance while a sword is equipped;
- the UAL1 `Sword_Attack` low-to-high diagonal slash;
- a normalized `0.49` contact point so damage text appears when the blade
  reaches its target;
- a sword-safe jog made by blending the right-arm portion of `Sword_Idle` into
  the normal `Jog_Fwd` animation.

The blended jog preserves the original leg locomotion and timing. The
`move_pose_bone_names` and `move_pose_blend` properties are the main tuning
controls if the sword arm needs to move farther from or closer to the body.

`basic_attack_impact_fraction` is the gameplay contact point, expressed as a
portion of one attack cycle. Keep `fit_basic_attack_animation_to_cycle` enabled
when the full clip should speed up or slow down with Auto-Attack Speed. This
keeps the animation, damage application, and floating damage number on the same
timeline.

When a future weapon pack includes a complete run clip, set
`move_animation_name_override` instead. `combat_animation_scene_path` can point
at an item-specific GLB or scene; when blank, the player's shared animation
library is used.
