## Item-owned animation overrides for equipped tools and weapons.
##
## Keep this as data, not behavior-heavy code. A tool/weapon definition points
## at one profile, and PlayerAnimationController asks the profile which clip to
## play for a given action context.
class_name EquipmentAnimationProfile
extends Resource

## Short label for artists/designers browsing profile resources.
@export var profile_id := ""
## Optional clip library for this item's idle, movement, and attack animations.
## Blank means the character's normal source animation scene is used.
@export_file("*.glb", "*.gltf", "*.tscn") var combat_animation_scene_path := ""
## Optional full-body idle clip used while this item is equipped.
@export var idle_animation_name_override: StringName = &""
## Optional authored full-body locomotion clip. Leave blank to keep the normal jog.
@export var move_animation_name_override: StringName = &""
## Optional pose sampled and blended into the normal jog for the listed bones.
## This is useful when a weapon needs a safer arm position but no bespoke run exists.
@export var move_pose_animation_name: StringName = &""
@export var move_pose_bone_names: PackedStringArray = PackedStringArray()
@export_range(0.0, 1.0, 0.01) var move_pose_blend := 0.0
## Optional clip library used only for the basic attack animation.
## This lets locomotion and attacks come from different animation packs.
@export_file("*.glb", "*.gltf", "*.tscn") var basic_attack_animation_scene_path := ""
## Optional one-shot basic attack clip used while this item is equipped.
@export var basic_attack_animation_name: StringName = &""
## Normalized point in the attack cycle where gameplay damage should land.
## A negative value keeps the combat component's generic timing.
@export_range(-1.0, 0.95, 0.01) var basic_attack_impact_fraction := -1.0
## Fits the complete attack clip to one stat-driven auto-attack cycle.
@export var fit_basic_attack_animation_to_cycle := false
## Optional local animation export for this item, usually beside this profile.
@export_file("*.glb", "*.gltf", "*.tscn") var gathering_animation_scene_path := ""
## Fallback gathering clip when a specific resource-family override is empty.
@export var default_gathering_animation_name: StringName = &""
## Gathering clip overrides by current resource family.
@export var logs_gathering_animation_name: StringName = &""
@export var stone_gathering_animation_name: StringName = &""
@export var ore_gathering_animation_name: StringName = &""
@export var cotton_gathering_animation_name: StringName = &""
@export var hide_gathering_animation_name: StringName = &""
## Returns the best gathering clip for the resource family, or an empty value.
func get_gathering_animation_name(resource_family_id: String) -> StringName:
	var family_animation_name := _gathering_animation_for_family(resource_family_id)
	if not String(family_animation_name).is_empty():
		return family_animation_name

	return default_gathering_animation_name


func _gathering_animation_for_family(resource_family_id: String) -> StringName:
	match resource_family_id:
		"logs":
			return logs_gathering_animation_name
		"stone":
			return stone_gathering_animation_name
		"ore":
			return ore_gathering_animation_name
		"cotton":
			return cotton_gathering_animation_name
		"hide":
			return hide_gathering_animation_name
		_:
			return &""
