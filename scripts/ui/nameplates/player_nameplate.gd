@tool
## Renders a compact player nameplate into a transparent 2D viewport, then
## displays that viewport as a billboarded Sprite3D above the character.
##
## The first letter, player name, alliance tag, guild name, health bar, and mana
## bar are regular UI controls so the layout can evolve quickly while the art
## direction is still changing.
class_name PlayerNameplate
extends Node3D

## Temporary player name until character identity is wired in.
@export var player_name: String = "PLAYER"
## Placeholder alliance tag shown before the guild name.
@export var alliance_tag: String = "TAG"
## Placeholder guild name. Leave empty later to hide guild/alliance text.
@export var guild_name: String = "GUILD NAME"
## Current health ratio from 0.0 to 1.0.
@export_range(0.0, 1.0, 0.01) var health_ratio: float = 1.0
## Current mana ratio from 0.0 to 1.0.
@export_range(0.0, 1.0, 0.01) var mana_ratio: float = 1.0
## Pixel dimensions of the offscreen UI canvas.
@export var viewport_size := Vector2i(360, 144)
## World units per viewport pixel.
@export_range(0.001, 0.01, 0.0001) var world_pixel_size: float = 0.003
## Keep the rendered nameplate facing the active camera.
@export var billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED
## Draw over world geometry so the local player name stays readable.
@export var no_depth_test: bool = true

@export_group("Visibility")
## Keeps this nameplate visible even when it is not tied to a selected target.
@export var show_when_unselected: bool = true
## Optional selectable target used to show this nameplate only while selected.
@export var selectable_path: NodePath
## Optional health source used to drive the health bar ratio.
@export var health_source_path: NodePath

@export_group("Camera Scaling")
## Keeps the nameplate the same screen size while a perspective camera zooms.
@export var keep_screen_size_on_zoom: bool = true
## Lowers the nameplate anchor as the camera zooms in so it stays visually attached.
@export var compensate_height_on_zoom: bool = true
## How strongly zoom-in distance lowers the local Y position. Zero disables movement.
@export_range(0.0, 1.0, 0.01) var zoom_height_compensation_strength: float = 0.45
## Reference distance for the exported world pixel size. Zero captures it at runtime.
@export_range(0.0, 200.0, 0.1) var screen_size_reference_distance: float = 0.0

@export_group("Layout")
## Width used to horizontally center the nameplate contents inside the viewport.
@export var content_width: float = 242.0
## Top Y position of the nameplate contents inside the viewport.
@export var content_y: float = 24.0
## Recenters the generated controls after text widths are known.
@export var center_content_horizontally: bool = true
## Centers each visual row, such as name, guild, and bars, around the anchor.
@export var center_rows_horizontally: bool = true
## Expands the viewport width when long names would otherwise clip.
@export var auto_resize_viewport_width: bool = true
## Empty pixels kept on each side after auto-resizing for long names.
@export_range(0.0, 128.0, 1.0) var viewport_horizontal_padding: float = 24.0
## Offset from the first-letter emblem to the rest of the player name.
@export var name_text_offset := Vector2(40.0, 5.0)
## Offset from the first-letter emblem to the alliance/guild line.
@export var guild_line_offset := Vector2(12.0, 48.0)
## Offset from the first-letter emblem to the health/mana bars.
@export var status_bars_offset := Vector2(62.0, 72.0)

@export_group("First Letter")
## Moves the full first-letter badge, including the background and text glyph.
@export var first_letter_offset := Vector2.ZERO
## Position of the outer colored badge behind the first letter.
@export var emblem_outer_offset := Vector2(-4.0, 5.0)
## Size of the outer colored badge behind the first letter.
@export var emblem_outer_size := Vector2(36.0, 42.0)
## Position of the inner dark badge behind the first letter.
@export var emblem_inner_offset := Vector2(-1.0, 8.0)
## Size of the inner dark badge behind the first letter.
@export var emblem_inner_size := Vector2(30.0, 36.0)
## Position of the regular first-letter text inside the badge.
@export var first_letter_label_offset := Vector2(-1.0, 8.0)
## Size of the regular first-letter text box.
@export var first_letter_label_size := Vector2(30.0, 36.0)
## Optional font used only by the regular first-letter text.
@export var first_letter_font: Font
## Font size for the regular first-letter text.
@export_range(8, 72, 1) var first_letter_font_size: int = 28
## Outline size for the regular first-letter text.
@export_range(0, 12, 1) var first_letter_outline_size: int = 2

@export_group("Text")
## Shows the first-letter badge and player name row.
@export var show_name_row: bool = true
## Shows the alliance/guild text row.
@export var show_guild_line: bool = true
## Font size for the non-emblem portion of the player name.
@export var name_font_size: int = 28
## Font size for alliance and guild text.
@export var guild_font_size: int = 13
## Outline size for the player name.
@export var name_outline_size: int = 4
## Outline size for alliance and guild text.
@export var guild_outline_size: int = 2
## Size of the non-emblem player name label.
@export var name_label_size := Vector2(190.0, 38.0)
## Size of the alliance tag label.
@export var alliance_label_size := Vector2(50.0, 20.0)
## Offset from the alliance tag to the guild label.
@export var guild_label_offset := Vector2(44.0, 0.0)
## Size of the guild name label.
@export var guild_label_size := Vector2(188.0, 20.0)

@export_group("Bars")
## Shows the health bar row.
@export var show_health_bar: bool = true
## Shows the mana bar row.
@export var show_mana_bar: bool = true
## Uses the linked selectable relationship color for the health bar.
@export var use_relationship_health_color: bool = false
## Fallback health bar fill color.
@export var health_fill_color := Color(0.86, 0.64, 0.17, 1.0)
## Mana bar fill color.
@export var mana_fill_color := Color(0.18, 0.48, 0.86, 1.0)
## Size of the health and mana bars.
@export var status_bar_size := Vector2(132.0, 8.0)
## Vertical spacing between the health bar and mana bar.
@export var status_bar_gap: float = 10.0
## Number of readable chunks inside each status bar.
@export_range(1, 20, 1) var status_bar_segments: int = 5
## Pixel gap between status bar chunks.
@export_range(0.0, 12.0, 0.5) var status_bar_segment_gap: float = 2.0

var _viewport: SubViewport
var _root: Control
var _sprite: Sprite3D
var _last_editor_signature := ""
var _base_local_position := Vector3.ZERO
var _runtime_reference_camera_distance := 0.0
var _center_rows := []
var _selectable: Node
var _health_source: Node


func _ready() -> void:
	_base_local_position = position
	_create_viewport_renderer()
	_connect_selectable()
	_connect_health_source()
	_rebuild()
	_sync_selection_visibility()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_update_billboard_pixel_size()
		return

	var signature := _build_editor_signature()
	if signature == _last_editor_signature:
		return

	_last_editor_signature = signature
	_apply_viewport_settings()
	_rebuild()


## Updates the displayed player name.
func set_player_name(new_name: String) -> void:
	player_name = new_name
	_rebuild()


## Updates the guild and alliance placeholder text.
func set_guild_info(new_guild_name: String, new_alliance_tag: String = "") -> void:
	guild_name = new_guild_name
	alliance_tag = new_alliance_tag
	_rebuild()


## Updates the health and mana bar fill ratios.
func set_vitals(new_health_ratio: float, new_mana_ratio: float) -> void:
	health_ratio = clampf(new_health_ratio, 0.0, 1.0)
	mana_ratio = clampf(new_mana_ratio, 0.0, 1.0)
	_rebuild()


func _create_viewport_renderer() -> void:
	if _viewport != null:
		_apply_viewport_settings()
		return

	_remove_generated_renderer()

	_viewport = SubViewport.new()
	_viewport.name = "NameplateViewport"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if Engine.is_editor_hint() else SubViewport.UPDATE_ONCE
	add_child(_viewport)

	_root = Control.new()
	_root.name = "NameplateRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_root)

	_sprite = Sprite3D.new()
	_sprite.name = "NameplateSprite"
	_sprite.texture = _viewport.get_texture()
	_sprite.centered = true
	add_child(_sprite)
	_apply_viewport_settings()


func _connect_selectable() -> void:
	_selectable = _find_selectable()
	if _selectable == null:
		return

	if Engine.is_editor_hint():
		return

	var selection_changed_callable := Callable(self, "_on_selection_changed")
	if (
		_selectable.has_signal("selection_changed")
		and not _selectable.is_connected("selection_changed", selection_changed_callable)
	):
		_selectable.connect("selection_changed", selection_changed_callable)


func _connect_health_source() -> void:
	_health_source = _find_health_source()
	if _health_source == null:
		return

	if Engine.is_editor_hint():
		return

	var health_changed_callable := Callable(self, "_on_health_changed")
	if (
		_health_source.has_signal("health_changed")
		and not _health_source.is_connected("health_changed", health_changed_callable)
	):
		_health_source.connect("health_changed", health_changed_callable)

	_sync_health_ratio_from_source()


func _find_selectable() -> Node:
	if selectable_path != NodePath(""):
		var explicit_selectable := get_node_or_null(selectable_path)
		if explicit_selectable != null:
			return explicit_selectable

	var parent_node := get_parent()
	if parent_node != null:
		return parent_node.get_node_or_null("Selectable")

	return null


func _find_health_source() -> Node:
	if health_source_path != NodePath(""):
		var explicit_health_source := get_node_or_null(health_source_path)
		if explicit_health_source != null:
			return explicit_health_source

	var parent_node := get_parent()
	if parent_node != null:
		return parent_node.get_node_or_null("Health")

	return null


func _on_selection_changed(_is_selected: bool) -> void:
	_rebuild()
	_sync_selection_visibility()


func _on_health_changed(_current_health: float, _max_health: float, new_health_ratio: float) -> void:
	health_ratio = clampf(new_health_ratio, 0.0, 1.0)
	_rebuild()


func _sync_health_ratio_from_source() -> void:
	if _health_source == null:
		return

	if not Engine.is_editor_hint() and _health_source.has_method("get_health_ratio"):
		health_ratio = clampf(_health_source.call("get_health_ratio"), 0.0, 1.0)


func _sync_selection_visibility() -> void:
	if show_when_unselected:
		visible = true
		return

	if _selectable == null:
		_connect_selectable()

	visible = _is_selectable_selected()


func _is_selectable_selected() -> bool:
	return (
		not Engine.is_editor_hint()
		and
		_selectable != null
		and _selectable.has_method("is_selected")
		and _selectable.call("is_selected") == true
	)


func _remove_generated_renderer() -> void:
	for generated_node_name in ["NameplateViewport", "NameplateSprite"]:
		var existing_node := get_node_or_null(generated_node_name)
		if existing_node != null:
			existing_node.free()


func _apply_viewport_settings() -> void:
	if _viewport != null:
		_viewport.size = viewport_size
	if _root != null:
		_root.size = Vector2(viewport_size)
	if _sprite != null:
		_sprite.billboard = billboard_mode
		_sprite.no_depth_test = no_depth_test
		_sprite.pixel_size = world_pixel_size


func _update_billboard_pixel_size() -> void:
	if _sprite == null:
		return

	if Engine.is_editor_hint():
		_sprite.pixel_size = world_pixel_size
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_sprite.pixel_size = world_pixel_size
		_reset_zoom_height_compensation()
		return

	var camera_distance := camera.global_position.distance_to(global_position)
	if camera_distance <= 0.001:
		_sprite.pixel_size = world_pixel_size
		_reset_zoom_height_compensation()
		return

	var reference_distance := _get_screen_size_reference_distance(camera_distance)
	var distance_ratio := camera_distance / reference_distance
	_sprite.pixel_size = world_pixel_size * distance_ratio if keep_screen_size_on_zoom else world_pixel_size
	_update_zoom_height_compensation(distance_ratio)


func _update_zoom_height_compensation(distance_ratio: float) -> void:
	if not compensate_height_on_zoom:
		_reset_zoom_height_compensation()
		return

	var zoomed_in_ratio := clampf(distance_ratio, 0.0, 1.0)
	var height_scale := lerpf(1.0, zoomed_in_ratio, zoom_height_compensation_strength)
	position = Vector3(
		_base_local_position.x,
		_base_local_position.y * height_scale,
		_base_local_position.z
	)


func _reset_zoom_height_compensation() -> void:
	position = _base_local_position


func _get_screen_size_reference_distance(current_distance: float) -> float:
	if screen_size_reference_distance > 0.001:
		return screen_size_reference_distance

	if _runtime_reference_camera_distance <= 0.001:
		_runtime_reference_camera_distance = current_distance

	return _runtime_reference_camera_distance


func _rebuild() -> void:
	if _root == null:
		return

	_apply_viewport_settings()
	_clear_root()
	_center_rows.clear()
	if _health_source == null:
		_connect_health_source()
	else:
		_sync_health_ratio_from_source()
	var name_text := _display_name()
	var first_letter := name_text.substr(0, 1).to_upper()
	var remaining_name := name_text.substr(1)
	var content_origin := Vector2((float(viewport_size.x) - content_width) * 0.5, content_y)

	if show_name_row:
		var name_row := _add_first_letter_emblem(first_letter, content_origin + first_letter_offset)
		name_row.append(_add_player_name_text(remaining_name, content_origin + name_text_offset))
		_register_center_row(name_row)
	if show_guild_line:
		_register_center_row(_add_guild_line(content_origin + guild_line_offset))
	_register_center_row(_add_status_bars(content_origin + status_bars_offset))
	_fit_and_center_contents()
	_request_viewport_render()


func _clear_root() -> void:
	for child in _root.get_children():
		child.free()


func _request_viewport_render() -> void:
	if _viewport == null or Engine.is_editor_hint():
		return

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _display_name() -> String:
	var trimmed := player_name.strip_edges()
	return "PLAYER" if trimmed.is_empty() else trimmed


func _add_first_letter_emblem(letter: String, position: Vector2) -> Array:
	var controls := []
	controls.append(_add_color_rect(position + emblem_outer_offset, emblem_outer_size, Color(0.94, 0.84, 0.24, 1.0)))
	controls.append(_add_color_rect(position + emblem_inner_offset, emblem_inner_size, Color(0.13, 0.18, 0.12, 0.94)))

	var letter_label := _create_label(letter, first_letter_font_size, Color(1.0, 0.92, 0.42, 1.0), Color.BLACK, first_letter_outline_size)
	if first_letter_font != null:
		letter_label.add_theme_font_override("font", first_letter_font)
	letter_label.position = position + first_letter_label_offset
	letter_label.size = first_letter_label_size
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(letter_label)
	controls.append(letter_label)
	return controls


func _add_player_name_text(text: String, position: Vector2) -> Label:
	var label := _create_label(text, name_font_size, Color.WHITE, Color.BLACK, name_outline_size)
	label.position = position
	_root.add_child(label)
	_size_label_to_text(label, name_label_size)
	return label


func _add_guild_line(position: Vector2) -> Array:
	if guild_name.strip_edges().is_empty():
		return []

	var controls := []
	var alliance_text := "[%s]" % alliance_tag.strip_edges().to_upper()
	var alliance_label := _create_label(alliance_text, guild_font_size, Color(0.62, 0.86, 0.28, 1.0), Color.BLACK, guild_outline_size)
	alliance_label.position = position
	_root.add_child(alliance_label)
	_size_label_to_text(alliance_label, alliance_label_size)
	controls.append(alliance_label)

	var guild_label := _create_label(guild_name.strip_edges().to_upper(), guild_font_size, Color(0.96, 0.72, 0.26, 1.0), Color.BLACK, guild_outline_size)
	guild_label.position = position + guild_label_offset
	_root.add_child(guild_label)
	_size_label_to_text(guild_label, guild_label_size)
	controls.append(guild_label)
	return controls


func _add_status_bars(position: Vector2) -> Array:
	var controls := []
	var bar_position := position
	if show_health_bar:
		controls.append_array(_add_meter_bar(bar_position, status_bar_size, health_ratio, _get_health_fill_color()))
		bar_position.y += status_bar_gap
	if show_mana_bar:
		controls.append_array(_add_meter_bar(bar_position, status_bar_size, mana_ratio, mana_fill_color))
	return controls


func _add_meter_bar(position: Vector2, size: Vector2, ratio: float, fill_color: Color) -> Array:
	var controls := []
	controls.append(_add_color_rect(position + Vector2(-2.0, -2.0), size + Vector2(4.0, 4.0), Color(0.02, 0.02, 0.02, 0.95)))

	var safe_segment_count: int = maxi(status_bar_segments, 1)
	var total_gap_width := status_bar_segment_gap * float(safe_segment_count - 1)
	var segment_width := maxf((size.x - total_gap_width) / float(safe_segment_count), 1.0)
	var clamped_ratio := clampf(ratio, 0.0, 1.0)

	for segment_index in range(safe_segment_count):
		var segment_position := position + Vector2(float(segment_index) * (segment_width + status_bar_segment_gap), 0.0)
		var segment_size := Vector2(segment_width, size.y)
		var segment_fill := clampf((clamped_ratio * float(safe_segment_count)) - float(segment_index), 0.0, 1.0)

		controls.append(_add_color_rect(segment_position, segment_size, Color(0.08, 0.07, 0.04, 0.95)))
		if segment_fill > 0.0:
			controls.append(_add_color_rect(segment_position, Vector2(segment_width * segment_fill, size.y), fill_color))

	return controls


func _add_color_rect(position: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = position
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	return rect


func _get_health_fill_color() -> Color:
	if (
		use_relationship_health_color
		and not Engine.is_editor_hint()
		and _selectable != null
		and _selectable.has_method("get_relationship_color")
	):
		return _selectable.call("get_relationship_color")

	return health_fill_color


func _create_label(
	text: String,
	font_size: int,
	font_color: Color,
	outline_color: Color,
	outline_size: int
) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _size_label_to_text(label: Label, fallback_size: Vector2) -> void:
	var text_size := label.get_combined_minimum_size()
	label.size = Vector2(maxf(text_size.x, 1.0), maxf(text_size.y, fallback_size.y))


func _register_center_row(controls: Array) -> void:
	if not controls.is_empty():
		_center_rows.append(controls)


func _fit_and_center_contents() -> void:
	var bounds := _get_content_bounds()
	if bounds.size == Vector2.ZERO:
		return

	if auto_resize_viewport_width:
		var desired_width := maxi(
			viewport_size.x,
			int(ceilf(bounds.size.x + viewport_horizontal_padding * 2.0))
		)
		_resize_viewport_width(desired_width)

	if center_rows_horizontally:
		_center_registered_rows()

	if center_content_horizontally:
		_center_contents(_get_content_bounds())


func _center_registered_rows() -> void:
	var viewport_width := float(_viewport.size.x) if _viewport != null else float(viewport_size.x)

	for row in _center_rows:
		var bounds := _get_controls_bounds(row)
		if bounds.size == Vector2.ZERO:
			continue

		var offset_x := viewport_width * 0.5 - bounds.get_center().x
		if absf(offset_x) <= 0.01:
			continue

		for item in row:
			var control := item as Control
			if control != null:
				control.position.x += offset_x


func _get_content_bounds() -> Rect2:
	return _get_controls_bounds(_root.get_children())


func _get_controls_bounds(controls: Array) -> Rect2:
	var has_bounds := false
	var bounds := Rect2()

	for item in controls:
		var control := item as Control
		if control == null or not control.visible:
			continue

		var child_bounds := Rect2(control.position, control.size)
		if not has_bounds:
			bounds = child_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(child_bounds)

	return bounds if has_bounds else Rect2()


func _resize_viewport_width(width: int) -> void:
	if _viewport == null or _root == null:
		return

	var safe_width := maxi(width, viewport_size.x)
	var resized_viewport_size := Vector2i(safe_width, viewport_size.y)
	_viewport.size = resized_viewport_size
	_root.size = Vector2(resized_viewport_size)


func _center_contents(bounds: Rect2) -> void:
	var viewport_width := float(_viewport.size.x) if _viewport != null else float(viewport_size.x)
	var offset_x := viewport_width * 0.5 - bounds.get_center().x
	if absf(offset_x) <= 0.01:
		return

	for child in _root.get_children():
		var control := child as Control
		if control != null:
			control.position.x += offset_x


func _build_editor_signature() -> String:
	return str([
		player_name,
		alliance_tag,
		guild_name,
		health_ratio,
		mana_ratio,
		viewport_size,
		world_pixel_size,
		billboard_mode,
		no_depth_test,
		show_when_unselected,
		selectable_path,
		health_source_path,
		keep_screen_size_on_zoom,
		compensate_height_on_zoom,
		zoom_height_compensation_strength,
		screen_size_reference_distance,
		content_width,
		content_y,
		center_content_horizontally,
		center_rows_horizontally,
		auto_resize_viewport_width,
		viewport_horizontal_padding,
		name_text_offset,
		guild_line_offset,
		status_bars_offset,
		first_letter_offset,
		emblem_outer_offset,
		emblem_outer_size,
		emblem_inner_offset,
		emblem_inner_size,
		first_letter_label_offset,
		first_letter_label_size,
		first_letter_font,
		first_letter_font_size,
		first_letter_outline_size,
		show_name_row,
		show_guild_line,
		name_font_size,
		guild_font_size,
		name_outline_size,
		guild_outline_size,
		name_label_size,
		alliance_label_size,
		guild_label_offset,
		guild_label_size,
		show_health_bar,
		show_mana_bar,
		use_relationship_health_color,
		health_fill_color,
		mana_fill_color,
		status_bar_size,
		status_bar_gap,
		status_bar_segments,
		status_bar_segment_gap,
	])
