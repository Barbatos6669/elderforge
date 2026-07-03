## Item-owned animation overrides for equipped tools and weapons.
##
## Keep this as data, not behavior-heavy code. A tool/weapon definition points
## at one profile, and PlayerAnimationController asks the profile which clip to
## play for a given action context.
class_name EquipmentAnimationProfile
extends Resource

## Short label for artists/designers browsing profile resources.
@export var profile_id := ""
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
## Placeholder for weapon/tool combat work. The controller does not use this yet.
@export var basic_attack_animation_name: StringName = &""


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
