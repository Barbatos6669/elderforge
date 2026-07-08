## Animates simple transparent mist meshes for lightweight level atmosphere.
##
## This is visual-only. It should live under level content, not under gameplay
## objects, so collision, targeting, and gathering remain deterministic.
class_name AtmosphericMist3D
extends Node3D

## Runtime visibility. Keep the scene node hidden in the editor for clean level
## editing, then let this script restore it when the game starts.
@export var show_in_game := true
## Enables or disables visual drift without removing the mist patches.
@export var drift_enabled := true
## World direction used for the slow back-and-forth drift.
@export var drift_direction := Vector3(1.0, 0.0, 0.35)
## Maximum movement offset from each patch's authored position.
@export_range(0.0, 5.0, 0.05) var drift_amplitude := 0.35
## How quickly each mist patch drifts.
@export_range(0.01, 3.0, 0.01) var drift_speed := 0.18
## Small rotation wobble in degrees.
@export_range(0.0, 10.0, 0.1) var rotation_wobble_degrees := 1.2

var _elapsed := 0.0
var _patches: Array[MeshInstance3D] = []
var _base_transforms := {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = show_in_game
	_collect_patches(self)


func _process(delta: float) -> void:
	if not drift_enabled:
		_restore_base_transforms()
		return

	_elapsed += maxf(delta, 0.0)
	var direction := drift_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.RIGHT
	direction = direction.normalized()

	for patch in _patches:
		if patch == null or not is_instance_valid(patch):
			continue

		var base_transform: Transform3D = _base_transforms.get(patch)
		var phase := float(patch.get_instance_id() % 997) * 0.017
		var drift := sin(_elapsed * drift_speed + phase) * drift_amplitude
		var rotation_offset := deg_to_rad(sin(_elapsed * drift_speed * 0.73 + phase) * rotation_wobble_degrees)
		patch.transform = base_transform.translated(direction * drift)
		patch.rotation.y = base_transform.basis.get_euler().y + rotation_offset


func _collect_patches(node: Node) -> void:
	if node is MeshInstance3D:
		var patch := node as MeshInstance3D
		_patches.append(patch)
		_base_transforms[patch] = patch.transform

	for child in node.get_children():
		_collect_patches(child)


func _restore_base_transforms() -> void:
	for patch in _patches:
		if patch != null and is_instance_valid(patch):
			patch.transform = _base_transforms.get(patch, patch.transform)
