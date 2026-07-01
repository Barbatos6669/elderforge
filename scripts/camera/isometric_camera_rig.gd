extends Node3D

@export var target_path: NodePath
@export var follow_speed: float = 12.0
@export var camera_offset: Vector3 = Vector3(6.0, 14.0, 6.0)
@export var look_at_height: float = 0.0
@export_range(20.0, 90.0, 1.0) var field_of_view: float = 45.0
@export_range(0.25, 1.0, 0.01) var min_zoom_ratio: float = 0.45
@export_range(0.01, 0.25, 0.01) var zoom_step: float = 0.08
@export var zoom_smoothing: float = 14.0

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _current_zoom_ratio := 1.0
var _target_zoom_ratio := 1.0


func _ready() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D

	if _target != null:
		global_position = _target_focus_position()

	_configure_camera()
	_update_camera_transform()


func set_target(target: Node3D, snap_to_target: bool = true) -> void:
	_target = target

	if _target != null and snap_to_target:
		global_position = _target_focus_position()

	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return

	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_target_zoom(_target_zoom_ratio - zoom_step)
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_target_zoom(_target_zoom_ratio + zoom_step)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_zoom(delta)

	if _target != null:
		var weight: float = min(follow_speed * delta, 1.0)
		global_position = global_position.lerp(_target_focus_position(), weight)

	_update_camera_transform()


func _configure_camera() -> void:
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = field_of_view


func _update_camera_transform() -> void:
	camera.position = camera_offset * _current_zoom_ratio
	camera.look_at(global_position + Vector3.UP * look_at_height, Vector3.UP)


func _set_target_zoom(zoom_ratio: float) -> void:
	_target_zoom_ratio = clampf(zoom_ratio, min_zoom_ratio, 1.0)


func _update_zoom(delta: float) -> void:
	var zoom_step_delta := zoom_smoothing * delta
	_current_zoom_ratio = move_toward(_current_zoom_ratio, _target_zoom_ratio, zoom_step_delta)


func _target_focus_position() -> Vector3:
	var target_position := _target.global_position
	return target_position
