## Bottom-center HUD for abilities supplied by equipment and character systems.
##
## Eight stable circles reserve the action-bar footprint. Q/W/E belong to the
## weapon, R to chest armor, D to the helmet, and F to boots. The final two
## circles remain placeholders for future utility actions.
class_name WeaponAbilityHud
extends CanvasLayer

signal ability_activation_requested(slot_id: StringName)

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const WeaponAbilitySlotScript := preload("res://scripts/ui/hud/weapon_ability_slot.gd")
const AbilityTooltipPanelScript := preload("res://scripts/ui/hud/ability_tooltip_panel.gd")
const HudGrid := preload("res://scripts/ui/hud/hud_grid_layout.gd")
const AbilitySlots := preload(
	"res://scripts/combat/abilities/equipment_ability_slots.gd"
)
const Q_SLOT := &"q"
const SLOT_IDS := AbilitySlots.HUD_SLOT_IDS
const SLOT_KEY_HINTS := AbilitySlots.KEY_HINT_BY_SLOT
const HINT_VIEWPORT_MARGIN := Vector2(12.0, 12.0)

## PlayerWeaponAbilities component to observe.
@export var ability_component_path: NodePath
## Gap between the slot and the bottom edge of the viewport.
@export_range(0.0, 300.0, 1.0) var bottom_margin := 24.0
## Stable square slot size.
@export_range(48.0, 128.0, 1.0) var slot_size := 72.0
## Horizontal breathing room between adjacent spell slots.
@export_range(0.0, 32.0, 1.0) var slot_gap := 8.0
## Brief delay prevents the hint from flashing while the pointer crosses slots.
@export_range(0.0, 2.0, 0.05, "suffix:s") var hint_delay_seconds := 0.15

var _ability_component: Node
var _slots: Dictionary = {}
var _root: Control
var _hint_root: Control
var _hint_panel: Control
var _hint_timer: Timer
var _pending_hint_definition: Resource
var _visible_hint_definition: Resource


func _ready() -> void:
	layer = UiStyle.LAYER_HUD_ACTIONS
	_build_ui()
	call_deferred("_bind_ability_component")


func _build_ui() -> void:
	_root = Control.new()
	# Preserve this stable scene path for tests and any external HUD references.
	_root.name = "WeaponAbilityHudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudGrid.apply_zone(
		_root,
		HudGrid.Zone.BOTTOM_CENTER,
		Vector2(HudGrid.DEFAULT_OUTER_MARGIN.x, bottom_margin)
	)
	_root.resized.connect(_layout_slots)
	add_child(_root)
	_build_hint_layer()

	for slot_index in SLOT_IDS.size():
		var slot_id: StringName = SLOT_IDS[slot_index]
		var slot := WeaponAbilitySlotScript.new() as WeaponAbilitySlot
		slot.name = "%sAbilitySlot" % String(slot_id).to_upper()
		# A tiny explicit minimum prevents WeaponAbilitySlot from installing its
		# standalone 48px fallback before this responsive row lays it out.
		slot.custom_minimum_size = Vector2.ONE
		slot.set_key_hint(String(SLOT_KEY_HINTS[slot_id]))
		slot.ability_hint_requested.connect(_on_ability_hint_requested)
		slot.ability_hint_dismissed.connect(_on_ability_hint_dismissed)
		slot.ability_activation_requested.connect(_on_slot_activation_requested.bind(slot_id))
		_root.add_child(slot)
		_slots[slot_id] = slot
	call_deferred("_layout_slots")


func _build_hint_layer() -> void:
	_hint_root = Control.new()
	_hint_root.name = "AbilityHintRoot"
	_hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudGrid.apply_zone(_hint_root, HudGrid.Zone.MIDDLE_CENTER)
	# The middle-center zone still anchors the hint, but long spell details need
	# room to grow beyond the narrow center column.
	_hint_root.clip_contents = false
	_hint_root.resized.connect(_layout_hint_panel)
	add_child(_hint_root)

	_hint_panel = AbilityTooltipPanelScript.new() as Control
	_hint_panel.name = "AbilityHintPanel"
	_hint_panel.visible = false
	_hint_root.add_child(_hint_panel)
	_hint_panel.minimum_size_changed.connect(_layout_hint_panel)

	_hint_timer = Timer.new()
	_hint_timer.name = "AbilityHintDelay"
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_show_pending_hint)
	add_child(_hint_timer)
	call_deferred("_layout_hint_panel")


func _layout_slots() -> void:
	if _root == null or _slots.is_empty():
		return

	var available_size := _root.size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return

	var slot_count := SLOT_IDS.size()
	var minimum_preferred_slot_size := 32.0
	var effective_gap := minf(
		slot_gap,
		maxf(
			(available_size.x - minimum_preferred_slot_size * float(slot_count))
			/ float(maxi(slot_count - 1, 1)),
			0.0
		)
	)
	var width_after_gaps := maxf(
		available_size.x - effective_gap * float(maxi(slot_count - 1, 0)),
		1.0
	)
	var effective_slot_size := minf(
		slot_size,
		minf(width_after_gaps / float(slot_count), available_size.y)
	)
	var bar_width := (
		effective_slot_size * float(slot_count)
		+ effective_gap * float(maxi(slot_count - 1, 0))
	)
	var start_position := Vector2(
		maxf((available_size.x - bar_width) * 0.5, 0.0),
		maxf(available_size.y - effective_slot_size, 0.0)
	)

	for slot_index in SLOT_IDS.size():
		var slot := get_slot(SLOT_IDS[slot_index])
		if slot == null:
			continue
		slot.custom_minimum_size = Vector2(effective_slot_size, effective_slot_size)
		slot.position = start_position + Vector2(
			float(slot_index) * (effective_slot_size + effective_gap),
			0.0
		)
		slot.size = Vector2(effective_slot_size, effective_slot_size)


func _layout_hint_panel() -> void:
	if _hint_root == null or _hint_panel == null:
		return
	var available := _hint_root.size
	if available.x <= 0.0 or available.y <= 0.0:
		return

	var viewport_size := _hint_root.get_viewport_rect().size
	var max_width := maxf(viewport_size.x - HINT_VIEWPORT_MARGIN.x * 2.0, 1.0)
	var max_height := maxf(viewport_size.y - HINT_VIEWPORT_MARGIN.y * 2.0, 1.0)
	var minimum := _hint_panel.get_combined_minimum_size()
	var panel_size := Vector2(
		minf(AbilityTooltipPanelScript.TOOLTIP_WIDTH, max_width),
		minf(minimum.y, max_height)
	)
	var panel_position := (available - panel_size) * 0.5
	var root_position := _hint_root.global_position
	var min_position := HINT_VIEWPORT_MARGIN - root_position
	var max_position := viewport_size - HINT_VIEWPORT_MARGIN - panel_size - root_position
	panel_position.x = _clamp_hint_axis(panel_position.x, min_position.x, max_position.x)
	panel_position.y = _clamp_hint_axis(panel_position.y, min_position.y, max_position.y)
	_hint_panel.position = panel_position
	_hint_panel.size = panel_size


func _clamp_hint_axis(value: float, minimum: float, maximum: float) -> float:
	if maximum < minimum:
		return (minimum + maximum) * 0.5
	return clampf(value, minimum, maximum)


func _on_ability_hint_requested(definition: Resource) -> void:
	if definition == null:
		return
	_pending_hint_definition = definition
	if hint_delay_seconds <= 0.0:
		_show_pending_hint()
		return
	_hint_timer.start(hint_delay_seconds)


func _on_ability_hint_dismissed(definition: Resource) -> void:
	if definition != _pending_hint_definition and definition != _visible_hint_definition:
		return
	if definition == _pending_hint_definition:
		_hint_timer.stop()
		_pending_hint_definition = null
	if definition == _visible_hint_definition:
		_visible_hint_definition = null
		_hint_panel.visible = false


func _show_pending_hint() -> void:
	if _pending_hint_definition == null:
		return
	_visible_hint_definition = _pending_hint_definition
	_pending_hint_definition = null
	_hint_panel.call("set_ability", _visible_hint_definition)
	_hint_panel.visible = true
	call_deferred("_layout_hint_panel")


func _bind_ability_component() -> void:
	_ability_component = (
		get_node_or_null(ability_component_path)
		if ability_component_path != NodePath("")
		else null
	)
	if _ability_component == null:
		return

	if _ability_component.has_signal("ability_changed"):
		_ability_component.ability_changed.connect(_on_ability_changed)
	if _ability_component.has_signal("cooldown_changed"):
		_ability_component.cooldown_changed.connect(_on_cooldown_changed)
	_refresh_from_component()


func _refresh_from_component() -> void:
	if _ability_component == null:
		return

	for slot_id in SLOT_IDS:
		var slot := get_slot(slot_id)
		if slot == null:
			continue
		var definition: Resource = _ability_component.call("get_active_ability", slot_id)
		slot.set_ability(definition)
		slot.set_cooldown(
			float(_ability_component.call("get_cooldown_remaining", slot_id)),
			float(_ability_component.call("get_cooldown_total", slot_id))
		)


func _on_slot_activation_requested(slot_id: StringName) -> void:
	ability_activation_requested.emit(slot_id)
	if _ability_component == null:
		return
	var player_controller := _ability_component.get_parent()
	if player_controller != null and player_controller.has_method("request_ability_activation"):
		player_controller.call("request_ability_activation", slot_id, true)


func _on_ability_changed(slot_id: StringName, definition: Resource) -> void:
	var slot := get_slot(slot_id)
	if slot == null:
		return
	slot.set_ability(definition)


func _on_cooldown_changed(slot_id: StringName, remaining_seconds: float, total_seconds: float) -> void:
	var slot := get_slot(slot_id)
	if slot == null:
		return
	slot.set_cooldown(remaining_seconds, total_seconds)


## Returns one stable slot so future HUD binders can populate it by id.
func get_slot(slot_id: StringName) -> WeaponAbilitySlot:
	return _slots.get(slot_id) as WeaponAbilitySlot


func get_slot_count() -> int:
	return _slots.size()
