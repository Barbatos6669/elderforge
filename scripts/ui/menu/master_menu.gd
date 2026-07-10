## Fullscreen hub for opening game submenus.
##
## The master menu owns only navigation UI. Gameplay panels, such as inventory,
## still own their own data binding and presentation once opened.
class_name MasterMenu
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const MasterMenuStatIconScript := preload("res://scripts/ui/menu/master_menu_stat_icon.gd")
const MasterMenuTileIconScript := preload("res://scripts/ui/menu/master_menu_tile_icon.gd")
const MasterMenuCreaturePortraitScript := preload("res://scripts/ui/menu/master_menu_creature_portrait.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"

const BUTTONS := [
	{"id": "glossary", "label": "Glossary"},
	{"id": "alchemy", "label": "Alchemy"},
	{"id": "inventory", "label": "Inventory"},
	{"id": "world_map", "label": "World Map"},
	{"id": "quests", "label": "Quests"},
	{"id": "character", "label": "Character"},
]

const GLOSSARY_SUBMENU_BUTTONS := [
	{"id": "creatures", "label": "Creatures"},
	{"id": "tutorial", "label": "Tutorial"},
	{"id": "characters", "label": "Characters"},
	{"id": "books", "label": "Books"},
	{"id": "crafting", "label": "Crafting"},
]

const DETAIL_SEQUENCE := [
	{"id": "creatures", "label": "Creatures"},
	{"id": "tutorial", "label": "Tutorial"},
	{"id": "characters", "label": "Characters"},
	{"id": "books", "label": "Books"},
	{"id": "crafting", "label": "Crafting"},
	{"id": "alchemy", "label": "Alchemy"},
	{"id": "inventory", "label": "Inventory"},
	{"id": "world_map", "label": "World Map"},
	{"id": "quests", "label": "Quests"},
	{"id": "character", "label": "Character"},
]

const CATEGORY_NEWS := {
	"glossary": {
		"title": "Recent glossary entries",
		"entries": [
			{"tag": "Creatures", "title": "Corrupted Wolf"},
			{"tag": "Resources", "title": "Oak Wood"},
			{"tag": "Lore", "title": "Hearthbridge Charter"},
		],
	},
	"alchemy": {
		"title": "Recent alchemy discoveries",
		"entries": [
			{"tag": "Potion", "title": "Minor Healing Draught"},
			{"tag": "Ingredient", "title": "Moonleaf"},
			{"tag": "Crafting", "title": "Basic Mortar Recipes"},
		],
	},
	"inventory": {
		"title": "Recent inventory changes",
		"entries": [
			{"tag": "Tool", "title": "Tier IV Axe equipped"},
			{"tag": "Material", "title": "Oak Wood collected"},
			{"tag": "Currency", "title": "Silver auto-looted"},
		],
	},
	"world_map": {
		"title": "Recent map discoveries",
		"entries": [
			{"tag": "Place", "title": "Hearthbridge Outskirts"},
			{"tag": "Resource", "title": "Oak Stand"},
			{"tag": "Landmark", "title": "Old Bridge Shrine"},
		],
	},
	"quests": {
		"title": "Quest timeline",
		"entries": [
			{"tag": "Current", "title": "Repair the town gate"},
			{"tag": "Recent", "title": "Gather starter resources"},
			{"tag": "Completed", "title": "Enter Hearthbridge"},
		],
	},
	"character": {
		"title": "Character updates",
		"entries": [
			{"tag": "Appearance", "title": "Base character selected"},
			{"tag": "Combat", "title": "Auto-attack unlocked"},
			{"tag": "Stats", "title": "Max health set to 1200"},
		],
	},
}

const DETAIL_CONTENT := {
	"creatures": {
		"title": "Creatures",
		"left_title": "Known Creatures",
		"items": ["Wolf", "Corrupted Wolf", "Bandit"],
		"selected": "Wolf",
		"right_title": "Hearthvale Wolf",
		"description": "Wolves are common around Hearthvale forests, hills, and abandoned farms. They hunt in packs, test weak targets, and become much more dangerous when corrupted by Rift-scarred magic.\n\nFire, traps, noise, and separating the pack are the first lessons a Lantern Warden teaches new hunters.",
	},
	"tutorial": {
		"title": "Tutorial",
		"left_title": "Lessons",
		"items": ["Movement", "Gathering", "Combat"],
		"selected": "Gathering",
		"right_title": "Gathering Basics",
		"description": "Click a resource node to walk into range and begin channeling. Better tools gather faster, but tier one resources can still be gathered by hand at a slower rate.",
	},
	"characters": {
		"title": "Characters",
		"left_title": "Known People",
		"items": ["Player", "Hearthbridge Guard", "Tool Maker"],
		"selected": "Player",
		"right_title": "Player",
		"description": "A new arrival in Hearthbridge with a growing collection of tools, crafting notes, and unfinished town work.",
	},
	"books": {
		"title": "Books",
		"left_title": "Discovered Texts",
		"items": ["Hearthbridge Charter", "Broken Mill Notes", "Forgefaith Shrine Record"],
		"selected": "Hearthbridge Charter",
		"right_title": "Hearthbridge Charter",
		"description": "Hearthbridge survives through farming, fishing, lumber, mining, trade, and repair work for caravans. The old bridge is older than the town, and some say it was built during the Age of the Worldforge.",
	},
	"crafting": {
		"title": "Crafting",
		"left_title": "Recent Recipes",
		"items": ["Oak Beams", "Clay Blocks", "Iron Ingots", "Tier I Axe"],
		"selected": "Oak Beams",
		"right_title": "Oak Beams",
		"description": "Refined from Oak Wood at a sawmill. Tier one beams use four raw wood per beam; higher tiers will also require lower-tier refined wood.",
	},
	"alchemy": {
		"title": "Alchemy",
		"left_title": "Experiments",
		"items": ["Minor Healing Draught", "Moonleaf", "Grave Moss Poultice"],
		"selected": "Moonleaf",
		"right_title": "Moonleaf",
		"description": "A faintly glowing herb found in forests and moonlit groves. It is used in healing potions, anti-poison mixtures, monster oils, and calming tonics.",
	},
	"inventory": {
		"title": "Inventory",
		"left_title": "Recent Items",
		"items": ["Tools", "Materials", "Currency"],
		"selected": "Tools",
		"right_title": "Inventory Overview",
		"description": "This page will become the full inventory command center. For now it mirrors recent items and wallet changes from the player inventory.",
	},
	"world_map": {
		"title": "World Map",
		"left_title": "Discovered Places",
		"items": ["Hearthbridge", "Hearthvale", "Broken Mill", "Old Bridge Shrine"],
		"selected": "Hearthbridge",
		"right_title": "Hearthbridge",
		"description": "The first major settlement in Hearthvale. It sits beside an old stone bridge crossing the Emberwash River and anchors the first playtest region.",
	},
	"quests": {
		"title": "Quests",
		"left_title": "Quest Log",
		"items": ["Secure the Broken Mill", "Gather Hearthvale Resources", "Enter Hearthbridge"],
		"selected": "Secure the Broken Mill",
		"right_title": "Secure the Broken Mill",
		"description": "The abandoned mill outside Hearthbridge can introduce wolves, bandits, or a corruption investigation while teaching combat, tracking, and preparation.",
	},
	"character": {
		"title": "Character",
		"left_title": "Character Pages",
		"items": ["Stats", "Appearance", "Equipment"],
		"selected": "Stats",
		"right_title": "Character Overview",
		"description": "This page will show player stats, appearance, equipment, progression, and reputation in one place.",
	},
}

@export var inventory_panel_path: NodePath
@export var inventory_path: NodePath
@export var stats_path: NodePath
@export var start_visible := false
@export_range(64, 180, 1, "suffix:px") var button_size := 112
@export_range(0, 32, 1) var button_spacing := 10
@export_range(96, 220, 1, "suffix:px") var submenu_button_width := 156
@export_range(32, 72, 1, "suffix:px") var submenu_button_height := 46
@export_range(28, 72, 1, "suffix:px") var close_button_size := 42
@export_range(1, 100, 1) var player_level := 3
@export_range(0, 999999, 1) var level_progress_current := 605
@export_range(1, 999999, 1) var level_progress_required := 1000
@export_range(120, 360, 1, "suffix:px") var level_bar_width := 220
@export_range(1.0, 1000.0, 0.1, "suffix:kg") var fallback_max_load_kg := 50.0
@export_range(0, 96, 1, "suffix:px") var detail_top_offset := 34
@export_range(-96, 96, 1, "suffix:px") var detail_horizontal_offset := 0

var _root: Control
var _close_button: Button
var _inventory: Node
var _stats: Node
var _slot_usage_label: Label
var _weight_label: Label
var _silver_label: Label
var _level_value_label: Label
var _level_progress_bar: ProgressBar
var _level_progress_text: Label
var _hub_content: VBoxContainer
var _button_row: HBoxContainer
var _glossary_submenu_row: HBoxContainer
var _news_panel: VBoxContainer
var _news_title_label: Label
var _news_entries_row: HBoxContainer
var _detail_wrapper: HBoxContainer
var _detail_root: VBoxContainer
var _detail_previous_button: Button
var _detail_next_button: Button
var _detail_previous_label: Label
var _detail_next_label: Label
var _detail_title_label: Label
var _detail_body: HBoxContainer
var _status_label: Label
var _hidden_game_ui_states: Array[Dictionary] = []
var _button_highlights: Dictionary = {}
var _block_world_input_until_mouse_release := false
var _active_category_id := "glossary"
var _active_detail_id := ""


func _ready() -> void:
	layer = UiStyle.LAYER_MASTER_MENU
	add_to_group("master_menu")
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_build_ui()
	_bind_inventory()
	_bind_stats()
	visible = false
	if start_visible:
		open()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if _is_text_input_focused():
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and key_event.keycode == KEY_ESCAPE:
		if _is_detail_view_open():
			_return_to_hub()
		else:
			close()
		get_viewport().set_input_as_handled()


## Opens the fullscreen menu overlay.
func open() -> void:
	if visible:
		return

	_hide_game_ui()
	_bind_inventory()
	_bind_stats()
	_refresh_inventory_summary()
	visible = true
	_return_to_hub(false)
	_block_world_input_until_mouse_release = false
	_set_status("")


## Closes the fullscreen menu overlay.
func close() -> void:
	if not visible:
		return

	visible = false
	_return_to_hub(false)
	_restore_game_ui()
	_block_world_input_until_mouse_release = _is_world_move_mouse_button_down()


## Swaps between open and closed states.
func toggle() -> void:
	if visible:
		close()
	else:
		open()


## PlayerController checks this group method before reading world input.
func blocks_world_input() -> bool:
	if visible:
		return true

	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.018, 0.018, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 42)
	panel.add_child(margin)

	var center := CenterContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_theme_constant_override("separation", 20)
	center.add_child(layout)

	_hub_content = VBoxContainer.new()
	_hub_content.name = "HubContent"
	_hub_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_hub_content.custom_minimum_size = Vector2(980.0, 0.0)
	_hub_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hub_content.add_theme_constant_override("separation", 20)
	layout.add_child(_hub_content)

	var title := Label.new()
	title.text = "ELDERFORGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 38, 3)
	_hub_content.add_child(title)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", button_spacing)
	_hub_content.add_child(_button_row)
	_build_buttons()

	_glossary_submenu_row = HBoxContainer.new()
	_glossary_submenu_row.name = "GlossarySubmenu"
	_glossary_submenu_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_glossary_submenu_row.modulate.a = 0.0
	_glossary_submenu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glossary_submenu_row.custom_minimum_size = Vector2(0.0, submenu_button_height)
	_glossary_submenu_row.add_theme_constant_override("separation", 12)
	_hub_content.add_child(_glossary_submenu_row)
	_build_glossary_submenu_buttons()

	_news_panel = VBoxContainer.new()
	_news_panel.name = "CategoryNews"
	_news_panel.custom_minimum_size = Vector2(820.0, 132.0)
	_news_panel.add_theme_constant_override("separation", 16)
	_hub_content.add_child(_news_panel)
	_build_news_panel()

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_muted(_status_label, 13)
	_hub_content.add_child(_status_label)

	_build_detail_view(layout)

	_build_top_left_summary()
	_build_top_right_cluster()
	_refresh_level_display()
	_set_active_category("glossary")


func _build_buttons() -> void:
	for button_data in BUTTONS:
		var button_id := String(button_data["id"])
		var button_label := String(button_data["label"])
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.focus_mode = Control.FOCUS_NONE
		_apply_button_theme(button, 16)
		button.mouse_entered.connect(_on_main_button_mouse_entered.bind(button, button_id))
		button.mouse_exited.connect(_on_main_button_mouse_exited.bind(button, button_id))
		button.pressed.connect(_on_submenu_pressed.bind(button_id, button_label))
		_add_button_highlight(button)
		_add_button_contents(button, button_id, button_label)
		_button_row.add_child(button)


func _build_glossary_submenu_buttons() -> void:
	for button_data in GLOSSARY_SUBMENU_BUTTONS:
		var button_id := String(button_data["id"])
		var button_label := String(button_data["label"])
		var button := Button.new()
		button.name = "%sButton" % button_label.replace(" ", "")
		button.text = button_label.to_upper()
		button.custom_minimum_size = Vector2(submenu_button_width, submenu_button_height)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", UiStyle.master_menu_submenu_button_style(false))
		button.add_theme_stylebox_override("hover", UiStyle.master_menu_submenu_button_style(true))
		button.add_theme_stylebox_override("pressed", UiStyle.master_menu_submenu_button_style(true))
		button.pressed.connect(_on_glossary_submenu_pressed.bind(button_id, button_label))
		_glossary_submenu_row.add_child(button)


func _build_news_panel() -> void:
	_news_title_label = Label.new()
	_news_title_label.name = "Title"
	_news_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiStyle.label_muted(_news_title_label, 15)
	_news_panel.add_child(_news_title_label)

	_news_entries_row = HBoxContainer.new()
	_news_entries_row.name = "Entries"
	_news_entries_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_news_entries_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_news_entries_row.add_theme_constant_override("separation", 72)
	_news_panel.add_child(_news_entries_row)


func _refresh_news_panel() -> void:
	if _news_title_label == null or _news_entries_row == null:
		return

	var data := _category_news_data(_active_category_id)
	_news_title_label.text = String(data.get("title", "Recent updates"))

	for child in _news_entries_row.get_children():
		_news_entries_row.remove_child(child)
		child.queue_free()

	var entries := data.get("entries", []) as Array
	for entry in entries:
		var entry_data := entry as Dictionary
		if entry_data == null:
			continue
		_news_entries_row.add_child(_build_news_entry(entry_data))


func _category_news_data(category_id: String) -> Dictionary:
	if category_id == "inventory":
		return _inventory_news_data()

	return (CATEGORY_NEWS.get(category_id, CATEGORY_NEWS["glossary"]) as Dictionary).duplicate(true)


func _inventory_news_data() -> Dictionary:
	var entries: Array = []
	if _inventory != null and _inventory.has_method("get_display_slots"):
		var slots := _inventory.call("get_display_slots") as Array
		for slot in slots:
			var slot_data := slot as Dictionary
			if slot_data == null or slot_data.is_empty():
				continue

			entries.append({
				"tag": String(slot_data.get("category", "Item")),
				"title": "%s x%d" % [String(slot_data.get("name", "Item")), int(slot_data.get("quantity", 1))],
			})
			if entries.size() >= 2:
				break

	var silver := _inventory_silver()
	if silver > 0:
		entries.append({
			"tag": "Currency",
			"title": "%s silver carried" % _format_whole_number(silver),
		})

	if entries.is_empty():
		return (CATEGORY_NEWS["inventory"] as Dictionary).duplicate(true)

	return {
		"title": "Recent inventory changes",
		"entries": entries.slice(0, 3),
	}


func _build_news_entry(entry_data: Dictionary) -> Control:
	var entry := VBoxContainer.new()
	entry.name = "NewsEntry"
	entry.custom_minimum_size = Vector2(200.0, 54.0)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 4)

	var tag := Label.new()
	tag.name = "Tag"
	tag.text = String(entry_data.get("tag", "Update")).to_upper()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiStyle.label_muted(tag, 15)
	tag.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	entry.add_child(tag)

	var title := Label.new()
	title.name = "Title"
	title.text = String(entry_data.get("title", "New entry"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_primary(title, 16, 1)
	entry.add_child(title)
	return entry


func _build_detail_view(parent: Control) -> void:
	_detail_wrapper = HBoxContainer.new()
	_detail_wrapper.name = "DetailOffsetWrapper"
	_detail_wrapper.visible = false
	_detail_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(_detail_wrapper)

	_detail_root = VBoxContainer.new()
	_detail_root.name = "DetailView"
	_detail_root.visible = false
	_detail_root.custom_minimum_size = Vector2(1050.0, 570.0)
	_detail_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_root.add_theme_constant_override("separation", 18)

	if detail_horizontal_offset > 0:
		_detail_wrapper.add_child(_build_detail_offset_spacer())
	_detail_wrapper.add_child(_detail_root)
	if detail_horizontal_offset < 0:
		_detail_wrapper.add_child(_build_detail_offset_spacer())

	if detail_top_offset > 0:
		var top_spacer := Control.new()
		top_spacer.name = "DetailTopOffset"
		top_spacer.custom_minimum_size = Vector2(0.0, float(detail_top_offset))
		_detail_root.add_child(top_spacer)

	_detail_root.add_child(_build_rotary_header())

	var body_center := CenterContainer.new()
	body_center.name = "BodyCenter"
	body_center.custom_minimum_size = Vector2(1050.0, 430.0)
	body_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_root.add_child(body_center)

	_detail_body = HBoxContainer.new()
	_detail_body.name = "Body"
	_detail_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_body.custom_minimum_size = Vector2(1050.0, 430.0)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_body.add_theme_constant_override("separation", 0)
	body_center.add_child(_detail_body)


func _build_detail_offset_spacer() -> Control:
	var spacer := Control.new()
	spacer.name = "DetailHorizontalOffset"
	spacer.custom_minimum_size = Vector2(absf(float(detail_horizontal_offset)) * 2.0, 0.0)
	return spacer


func _build_rotary_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "RotaryHeader"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(360.0, 38.0)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.add_theme_constant_override("separation", 6)

	_detail_previous_label = _build_rotary_neighbor_label(HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(_detail_previous_label)

	_detail_previous_button = _build_rotary_button("Previous")
	_detail_previous_button.pressed.connect(_cycle_detail_view.bind(-1))
	header.add_child(_detail_previous_button)

	_detail_title_label = Label.new()
	_detail_title_label.name = "CurrentTitle"
	_detail_title_label.custom_minimum_size = Vector2(160.0, 34.0)
	_detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_detail_title_label, 20, 2)
	header.add_child(_detail_title_label)

	_detail_next_button = _build_rotary_button("Next")
	_detail_next_button.pressed.connect(_cycle_detail_view.bind(1))
	header.add_child(_detail_next_button)

	_detail_next_label = _build_rotary_neighbor_label(HORIZONTAL_ALIGNMENT_LEFT)
	header.add_child(_detail_next_label)
	return header


func _build_rotary_neighbor_label(alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(62.0, 28.0)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_muted(label, 9)
	label.add_theme_color_override("font_color", Color(0.58, 0.45, 0.28, 0.9))
	return label


func _build_rotary_button(tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(28.0, 28.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_submenu_button_style(false))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_submenu_button_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_submenu_button_style(true))
	return button


func _open_detail_view(detail_id: String) -> void:
	var normalized_id := _normalize_detail_id(detail_id)
	if normalized_id.is_empty():
		return

	_active_detail_id = normalized_id
	if _hub_content != null:
		_hub_content.visible = false
	if _detail_wrapper != null:
		_detail_wrapper.visible = true
	if _detail_root != null:
		_detail_root.visible = true
	_update_detail_view()


func _return_to_hub(reset_category: bool = true) -> void:
	_active_detail_id = ""
	if _detail_root != null:
		_detail_root.visible = false
	if _detail_wrapper != null:
		_detail_wrapper.visible = false
	if _hub_content != null:
		_hub_content.visible = true
	if reset_category:
		_set_active_category("glossary")
		_show_glossary_submenu()


func _is_detail_view_open() -> bool:
	return not _active_detail_id.is_empty()


func _cycle_detail_view(direction: int) -> void:
	if _active_detail_id.is_empty():
		_open_detail_view("creatures")
		return

	var next_index := wrapi(_detail_index(_active_detail_id) + direction, 0, DETAIL_SEQUENCE.size())
	var next_data := DETAIL_SEQUENCE[next_index] as Dictionary
	_open_detail_view(String(next_data.get("id", "creatures")))


func _update_detail_view() -> void:
	if _detail_title_label == null or _detail_body == null:
		return

	var data := _detail_content(_active_detail_id)
	_detail_title_label.text = String(data.get("title", _detail_label(_active_detail_id))).to_upper()
	_update_rotary_buttons()

	for child in _detail_body.get_children():
		_detail_body.remove_child(child)
		child.queue_free()

	if _active_detail_id == "creatures":
		_build_creatures_detail(data)
	else:
		_build_generic_detail(data)


func _update_rotary_buttons() -> void:
	var index := _detail_index(_active_detail_id)
	var previous_data := DETAIL_SEQUENCE[wrapi(index - 1, 0, DETAIL_SEQUENCE.size())] as Dictionary
	var next_data := DETAIL_SEQUENCE[wrapi(index + 1, 0, DETAIL_SEQUENCE.size())] as Dictionary
	if _detail_previous_button != null:
		_detail_previous_button.text = "<"
		_detail_previous_button.tooltip_text = String(previous_data.get("label", "Previous"))
	if _detail_next_button != null:
		_detail_next_button.text = ">"
		_detail_next_button.tooltip_text = String(next_data.get("label", "Next"))
	if _detail_previous_label != null:
		_detail_previous_label.text = String(previous_data.get("label", "Previous")).to_upper()
	if _detail_next_label != null:
		_detail_next_label.text = String(next_data.get("label", "Next")).to_upper()


func _build_creatures_detail(data: Dictionary) -> void:
	_detail_body.add_child(_build_detail_list_panel(data, 315.0))
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_creature_center_panel(data))
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_description_panel(data, 315.0))


func _build_generic_detail(data: Dictionary) -> void:
	_detail_body.add_child(_build_detail_list_panel(data, 315.0))
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_generic_center_panel(data))
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_description_panel(data, 315.0))


func _build_detail_column_spacer() -> Control:
	var spacer := Control.new()
	spacer.name = "ColumnSpacer"
	spacer.custom_minimum_size = Vector2(32.0, 0.0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _build_detail_list_panel(data: Dictionary, width: float) -> Control:
	var panel := PanelContainer.new()
	panel.name = "LeftPanel"
	panel.custom_minimum_size = Vector2(width, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	panel.add_child(_wrap_margin(layout, 8))

	var title := Label.new()
	title.text = String(data.get("left_title", "Entries")).to_upper()
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var items := data.get("items", []) as Array
	var selected := String(data.get("selected", ""))
	for item in items:
		layout.add_child(_build_detail_list_item(String(item), String(item) == selected))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	return panel


func _build_detail_list_item(label_text: String, is_selected: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 46.0)
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_item_style(is_selected))

	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(label, 14 if is_selected else 13, 1 if is_selected else 0)
	panel.add_child(_wrap_margin(label, 9))
	return panel


func _build_creature_center_panel(data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.custom_minimum_size = Vector2(315.0, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(_wrap_margin(layout, 14))

	var portrait := MasterMenuCreaturePortraitScript.new() as Control
	portrait.name = "CreaturePortrait"
	portrait.custom_minimum_size = Vector2(230.0, 230.0)
	layout.add_child(portrait)

	var title := Label.new()
	title.text = String(data.get("selected", "Creature")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 20, 2)
	layout.add_child(title)

	var vulnerable := Label.new()
	vulnerable.text = "VULNERABLE AGAINST"
	vulnerable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(vulnerable, 12)
	layout.add_child(vulnerable)

	var badges := HBoxContainer.new()
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 10)
	badges.add_child(_build_vulnerability_badge("FIRE"))
	badges.add_child(_build_vulnerability_badge("STEEL"))
	layout.add_child(badges)
	return panel


func _build_generic_center_panel(data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.custom_minimum_size = Vector2(315.0, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(_wrap_margin(layout, 14))

	var icon := MasterMenuTileIconScript.new() as Control
	icon.custom_minimum_size = Vector2(78.0, 78.0)
	icon.set("icon_id", _active_detail_id)
	layout.add_child(icon)

	var title := Label.new()
	title.text = String(data.get("selected", _detail_label(_active_detail_id))).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 20, 2)
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "PAGE PREVIEW"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(hint, 12)
	layout.add_child(hint)
	return panel


func _build_description_panel(data: Dictionary, width: float) -> Control:
	var panel := PanelContainer.new()
	panel.name = "RightPanel"
	panel.custom_minimum_size = Vector2(width, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(_wrap_margin(layout, 12))

	var title := Label.new()
	title.text = String(data.get("right_title", "Overview")).to_upper()
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var description := Label.new()
	description.text = String(data.get("description", "Details will appear here."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.label_muted(description, 14)
	layout.add_child(description)
	return panel


func _build_vulnerability_badge(label_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(70.0, 54.0)
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_item_style(true))

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(label, 13, 1)
	panel.add_child(label)
	return panel


func _wrap_margin(control: Control, margin_size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	margin.add_child(control)
	return margin


func _build_top_right_cluster() -> void:
	var cluster := HBoxContainer.new()
	cluster.name = "TopRightCluster"
	cluster.anchor_left = 1.0
	cluster.anchor_top = 0.0
	cluster.anchor_right = 1.0
	cluster.anchor_bottom = 0.0
	var cluster_width := 76.0 + 38.0 + float(level_bar_width) + float(close_button_size) + 42.0
	cluster.offset_left = -14.0 - cluster_width
	cluster.offset_top = 16.0
	cluster.offset_right = -14.0
	cluster.offset_bottom = 68.0
	cluster.alignment = BoxContainer.ALIGNMENT_END
	cluster.add_theme_constant_override("separation", 12)
	_root.add_child(cluster)

	var level_caption := Label.new()
	level_caption.name = "LevelCaption"
	level_caption.text = "LEVEL"
	level_caption.custom_minimum_size = Vector2(76.0, close_button_size)
	level_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_muted(level_caption, 20)
	cluster.add_child(level_caption)

	_level_value_label = Label.new()
	_level_value_label.name = "LevelValue"
	_level_value_label.custom_minimum_size = Vector2(38.0, close_button_size)
	_level_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_level_value_label, 34, 2)
	cluster.add_child(_level_value_label)

	var bar_column := VBoxContainer.new()
	bar_column.name = "LevelProgressColumn"
	bar_column.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_column.custom_minimum_size = Vector2(level_bar_width, close_button_size)
	bar_column.add_theme_constant_override("separation", 3)
	cluster.add_child(bar_column)

	_level_progress_bar = ProgressBar.new()
	_level_progress_bar.name = "LevelProgressBar"
	_level_progress_bar.custom_minimum_size = Vector2(level_bar_width, 18.0)
	_level_progress_bar.show_percentage = false
	_level_progress_bar.add_theme_stylebox_override("background", UiStyle.master_menu_level_bar_background_style())
	_level_progress_bar.add_theme_stylebox_override("fill", UiStyle.master_menu_level_bar_fill_style())
	bar_column.add_child(_level_progress_bar)

	_level_progress_text = Label.new()
	_level_progress_text.name = "LevelProgressText"
	_level_progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_progress_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_muted(_level_progress_text, 18)
	bar_column.add_child(_level_progress_text)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.tooltip_text = "Close"
	_close_button.custom_minimum_size = Vector2(close_button_size, close_button_size)
	_close_button.focus_mode = Control.FOCUS_NONE
	_apply_button_theme(_close_button, 18)
	_close_button.mouse_entered.connect(_set_button_highlighted.bind(_close_button, true))
	_close_button.mouse_exited.connect(_set_button_highlighted.bind(_close_button, false))
	_close_button.pressed.connect(close)
	_add_button_highlight(_close_button)
	cluster.add_child(_close_button)


func _build_top_left_summary() -> void:
	var summary := _build_inventory_summary()
	summary.name = "TopLeftInventorySummary"
	summary.anchor_left = 0.0
	summary.anchor_top = 0.0
	summary.anchor_right = 0.0
	summary.anchor_bottom = 0.0
	summary.offset_left = 22.0
	summary.offset_top = 16.0
	summary.offset_right = 462.0
	summary.offset_bottom = 68.0
	_root.add_child(summary)


func _build_inventory_summary() -> Control:
	var row := HBoxContainer.new()
	row.name = "InventorySummary"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.custom_minimum_size = Vector2(440.0, close_button_size)
	row.add_theme_constant_override("separation", 18)

	var slot_row := _build_stat_readout(
		"SlotUsage",
		MasterMenuStatIconScript.IconKind.BAG,
		"0 / 0",
		104.0
	)
	_slot_usage_label = slot_row.get_node("Value") as Label
	row.add_child(slot_row)

	var weight_row := _build_stat_readout(
		"Weight",
		MasterMenuStatIconScript.IconKind.WEIGHT,
		"0 / 50 kg",
		146.0
	)
	_weight_label = weight_row.get_node("Value") as Label
	row.add_child(weight_row)

	var silver_row := _build_stat_readout(
		"Silver",
		MasterMenuStatIconScript.IconKind.SILVER,
		"0",
		96.0
	)
	_silver_label = silver_row.get_node("Value") as Label
	row.add_child(silver_row)
	return row


func _build_stat_readout(readout_name: String, icon_kind: int, starting_text: String, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = readout_name
	row.alignment = BoxContainer.ALIGNMENT_END
	row.custom_minimum_size = Vector2(width, close_button_size)
	row.add_theme_constant_override("separation", 6)

	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = starting_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_primary(value_label, 20, 2)
	row.add_child(value_label)

	var icon := MasterMenuStatIconScript.new() as Control
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.set("icon_kind", icon_kind)
	row.add_child(icon)
	return row


func _add_button_contents(button: Button, icon_id: String, label_text: String) -> void:
	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var spacer_top := Control.new()
	spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer_top)

	var icon := MasterMenuTileIconScript.new() as Control
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(48.0, 48.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set("icon_id", icon_id)
	layout.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_primary(label, 13, 2)
	layout.add_child(label)

	var spacer_bottom := Control.new()
	spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer_bottom)


func _refresh_level_display() -> void:
	var required := maxi(level_progress_required, 1)
	var current := clampi(level_progress_current, 0, required)
	if _level_value_label != null:
		_level_value_label.text = str(maxi(player_level, 1))
	if _level_progress_bar != null:
		_level_progress_bar.max_value = float(required)
		_level_progress_bar.value = float(current)
	if _level_progress_text != null:
		_level_progress_text.text = "%d/%d" % [current, required]


func _bind_inventory() -> void:
	var next_inventory := _find_inventory()
	if next_inventory == _inventory:
		return

	_disconnect_inventory_signals()
	_inventory = next_inventory
	_connect_inventory_signals()
	_refresh_inventory_summary()


func _connect_inventory_signals() -> void:
	if _inventory == null:
		return

	if _inventory.has_signal("slots_changed"):
		var slots_callable := Callable(self, "_on_inventory_slots_changed")
		if not _inventory.is_connected("slots_changed", slots_callable):
			_inventory.connect("slots_changed", slots_callable)

	if _inventory.has_signal("currency_changed"):
		var currency_callable := Callable(self, "_on_inventory_currency_changed")
		if not _inventory.is_connected("currency_changed", currency_callable):
			_inventory.connect("currency_changed", currency_callable)


func _disconnect_inventory_signals() -> void:
	if _inventory == null:
		return

	var slots_callable := Callable(self, "_on_inventory_slots_changed")
	if _inventory.has_signal("slots_changed") and _inventory.is_connected("slots_changed", slots_callable):
		_inventory.disconnect("slots_changed", slots_callable)

	var currency_callable := Callable(self, "_on_inventory_currency_changed")
	if _inventory.has_signal("currency_changed") and _inventory.is_connected("currency_changed", currency_callable):
		_inventory.disconnect("currency_changed", currency_callable)


func _bind_stats() -> void:
	var next_stats := _find_stats()
	if next_stats == _stats:
		return

	_disconnect_stats_signals()
	_stats = next_stats
	_connect_stats_signals()
	_refresh_inventory_summary()


func _connect_stats_signals() -> void:
	if _stats == null:
		return

	var stat_callable := Callable(self, "_on_player_stat_changed")
	if _stats.has_signal("stat_changed") and not _stats.is_connected("stat_changed", stat_callable):
		_stats.connect("stat_changed", stat_callable)


func _disconnect_stats_signals() -> void:
	if _stats == null:
		return

	var stat_callable := Callable(self, "_on_player_stat_changed")
	if _stats.has_signal("stat_changed") and _stats.is_connected("stat_changed", stat_callable):
		_stats.disconnect("stat_changed", stat_callable)


func _on_inventory_slots_changed() -> void:
	_refresh_inventory_summary()


func _on_inventory_currency_changed(_silver: int, _gold: int) -> void:
	_refresh_inventory_summary()


func _on_player_stat_changed(_stat_id: StringName, _value: float) -> void:
	_refresh_inventory_summary()


func _refresh_inventory_summary() -> void:
	var slot_total := _inventory_slot_total()
	var slots_used := _inventory_slots_used()
	var silver := _inventory_silver()
	var carried_weight := _inventory_carried_weight()
	var max_load := _inventory_max_load()

	if _slot_usage_label != null:
		_slot_usage_label.text = "%d / %d" % [slots_used, slot_total]
	if _weight_label != null:
		_weight_label.text = "%s / %s kg" % [_format_decimal(carried_weight), _format_decimal(max_load)]
	if _silver_label != null:
		_silver_label.text = _format_whole_number(silver)


func _inventory_slot_total() -> int:
	if _inventory != null and _inventory.has_method("get_slot_count"):
		return maxi(int(_inventory.call("get_slot_count")), 0)

	return 0


func _inventory_slots_used() -> int:
	if _inventory == null or not _inventory.has_method("get_display_slots"):
		return 0

	var slots := _inventory.call("get_display_slots") as Array
	var used := 0
	for slot in slots:
		if slot is Dictionary and not (slot as Dictionary).is_empty():
			used += 1
	return used


func _inventory_silver() -> int:
	if _inventory != null and _inventory.has_method("get_silver"):
		return maxi(int(_inventory.call("get_silver")), 0)

	return 0


func _inventory_carried_weight() -> float:
	if _inventory == null or not _inventory.has_method("get_display_slots"):
		return 0.0

	var carried_weight := 0.0
	var slots := _inventory.call("get_display_slots") as Array
	for slot in slots:
		var slot_data := slot as Dictionary
		if slot_data == null or slot_data.is_empty():
			continue

		var quantity := float(slot_data.get("quantity", 1))
		var unit_weight := float(slot_data.get("unit_weight", 0.0))
		carried_weight += quantity * unit_weight

	return carried_weight


func _inventory_max_load() -> float:
	if _stats != null and _stats.has_method("get_stat"):
		var stat_max_load := float(_stats.call("get_stat", &"max_load"))
		if stat_max_load > 0.0:
			return stat_max_load

	return fallback_max_load_kg


func _apply_button_theme(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_button_style(false))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_button_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_button_style(true))


func _add_button_highlight(button: Button) -> void:
	var highlight := Panel.new()
	highlight.name = "HoverHighlight"
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.visible = false
	highlight.add_theme_stylebox_override("panel", UiStyle.master_menu_button_highlight_style())
	button.add_child(highlight)
	button.move_child(highlight, 0)
	_button_highlights[button] = highlight


func _set_button_highlighted(button: Button, is_highlighted: bool) -> void:
	var highlight := _button_highlights.get(button) as Control
	if highlight != null:
		highlight.visible = is_highlighted


func _on_main_button_mouse_entered(button: Button, button_id: String) -> void:
	_set_button_highlighted(button, true)
	_set_active_category(button_id)
	if button_id == "glossary":
		_show_glossary_submenu()
	else:
		_hide_glossary_submenu()


func _on_main_button_mouse_exited(button: Button, _button_id: String) -> void:
	_set_button_highlighted(button, false)


func _show_glossary_submenu() -> void:
	if _glossary_submenu_row != null:
		_glossary_submenu_row.modulate.a = 1.0
		_glossary_submenu_row.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_glossary_submenu() -> void:
	if _glossary_submenu_row != null:
		_glossary_submenu_row.modulate.a = 0.0
		_glossary_submenu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_active_category(category_id: String) -> void:
	if not CATEGORY_NEWS.has(category_id):
		category_id = "glossary"

	_active_category_id = category_id
	_refresh_news_panel()


func _on_submenu_pressed(submenu_id: String, _submenu_label: String) -> void:
	match submenu_id:
		"glossary":
			_show_glossary_submenu()
		_:
			_open_detail_view(submenu_id)


func _on_glossary_submenu_pressed(submenu_id: String, _submenu_label: String) -> void:
	_open_detail_view(submenu_id)


func _open_inventory() -> void:
	var inventory_panel := _find_inventory_panel()
	if inventory_panel == null:
		_set_status("Inventory panel not found.")
		return

	close()
	if inventory_panel.has_method("open"):
		inventory_panel.call("open")
	else:
		inventory_panel.set("visible", true)


func _find_inventory_panel() -> Node:
	if inventory_panel_path != NodePath(""):
		var panel := get_node_or_null(inventory_panel_path)
		if panel != null:
			return panel

	var panels := get_tree().get_nodes_in_group("inventory_panel")
	if panels.is_empty():
		return null

	return panels[0]


func _find_inventory() -> Node:
	if inventory_path != NodePath(""):
		var inventory := get_node_or_null(inventory_path)
		if inventory != null:
			return inventory

	return get_tree().get_first_node_in_group("player_inventory")


func _find_stats() -> Node:
	if stats_path != NodePath(""):
		var stats := get_node_or_null(stats_path)
		if stats != null:
			return stats

	return get_tree().get_first_node_in_group("player_stats")


func _normalize_detail_id(detail_id: String) -> String:
	for detail_data in DETAIL_SEQUENCE:
		var data := detail_data as Dictionary
		var id := String(data.get("id", ""))
		if id == detail_id:
			return id

	return ""


func _detail_index(detail_id: String) -> int:
	for index in range(DETAIL_SEQUENCE.size()):
		var data := DETAIL_SEQUENCE[index] as Dictionary
		if String(data.get("id", "")) == detail_id:
			return index

	return 0


func _detail_label(detail_id: String) -> String:
	for detail_data in DETAIL_SEQUENCE:
		var data := detail_data as Dictionary
		if String(data.get("id", "")) == detail_id:
			return String(data.get("label", detail_id.capitalize()))

	return detail_id.capitalize()


func _detail_content(detail_id: String) -> Dictionary:
	var content := DETAIL_CONTENT.get(detail_id, {}) as Dictionary
	if content.is_empty():
		return {
			"title": _detail_label(detail_id),
			"left_title": "Entries",
			"items": [],
			"selected": _detail_label(detail_id),
			"right_title": _detail_label(detail_id),
			"description": "Details will appear here as this section comes online.",
		}

	return content.duplicate(true)


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _hide_game_ui() -> void:
	_restore_game_ui()

	for canvas_layer in _collect_canvas_layers(get_tree().root):
		if canvas_layer == self:
			continue
		if _is_ancestor_of(canvas_layer, self) or _is_ancestor_of(self, canvas_layer):
			continue

		_hidden_game_ui_states.append({
			"node": canvas_layer,
			"visible": canvas_layer.visible,
		})
		canvas_layer.visible = false


func _restore_game_ui() -> void:
	for state in _hidden_game_ui_states:
		var node := state.get("node") as CanvasLayer
		if node == null or not is_instance_valid(node):
			continue
		node.visible = bool(state.get("visible", true))

	_hidden_game_ui_states.clear()


func _collect_canvas_layers(node: Node) -> Array[CanvasLayer]:
	var layers: Array[CanvasLayer] = []
	if node is CanvasLayer:
		layers.append(node)

	for child in node.get_children():
		layers.append_array(_collect_canvas_layers(child))

	return layers


func _is_ancestor_of(possible_ancestor: Node, node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent == possible_ancestor:
			return true
		parent = parent.get_parent()

	return false


func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _format_whole_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	var group_count := 0

	for index in range(digits.length() - 1, -1, -1):
		if group_count > 0 and group_count % 3 == 0:
			formatted = ",%s" % formatted
		formatted = "%s%s" % [digits.substr(index, 1), formatted]
		group_count += 1

	return formatted


func _format_decimal(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))

	return "%.1f" % value
