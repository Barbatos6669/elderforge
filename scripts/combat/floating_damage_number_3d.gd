## One short-lived 3D damage number.
##
## DamageNumberEmitter3D spawns this node when CombatHealth reports damage. The
## number faces the camera, rises, fades, and then frees itself.
class_name FloatingDamageNumber3D
extends Node3D

@export var lifetime := 0.9
@export var rise_distance := 0.75
@export var horizontal_drift := Vector3.ZERO
@export var font_size := 64
@export var pixel_size := 0.004
@export var text_color := Color(1.0, 0.88, 0.36, 1.0)
@export var outline_color := Color(1.0, 1.0, 1.0, 0.45)
## Highest Label3D priority so damage numbers draw over other 3D transparent text.
@export_range(-128, 127, 1) var render_priority := 127

var _amount := 0.0
var _age := 0.0
var _base_position := Vector3.ZERO
var _has_base_position := false
var _label: Label3D


func _ready() -> void:
	_build_label()
	_apply_label_state()


func _process(delta: float) -> void:
	if not _has_base_position:
		_base_position = position
		_has_base_position = true

	_age += maxf(delta, 0.0)
	var progress := clampf(_age / maxf(lifetime, 0.01), 0.0, 1.0)
	position = _base_position + horizontal_drift * progress + Vector3.UP * rise_distance * progress

	var fade := 1.0 - progress
	if _label != null:
		var faded_text_color := text_color
		faded_text_color.a *= fade
		_label.modulate = faded_text_color

		var faded_outline_color := outline_color
		faded_outline_color.a *= fade
		_label.outline_modulate = faded_outline_color

	if progress >= 1.0:
		queue_free()


## Sets the displayed damage amount before or after the node enters the tree.
func setup(amount: float, color: Color) -> void:
	_amount = maxf(amount, 0.0)
	text_color = color
	_apply_label_state()


func _build_label() -> void:
	if _label != null:
		return

	_label = Label3D.new()
	_label.name = "Label"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = render_priority
	_label.outline_render_priority = render_priority - 1
	_label.font_size = font_size
	_label.outline_size = 3
	_label.pixel_size = pixel_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func _apply_label_state() -> void:
	if _label == null:
		return

	_label.text = str(roundi(_amount))
	_label.modulate = text_color
	_label.outline_modulate = outline_color
