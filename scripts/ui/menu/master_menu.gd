## Fullscreen hub for opening game submenus.
##
## The master menu owns the active navigation shell. Prototype data still comes
## from feature modules such as PlayerInventory and PlayerStats.
class_name MasterMenu
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const CraftingRecipeCatalogScript := preload("res://scripts/crafting/crafting_recipe_catalog.gd")
const MasterMenuStatIconScript := preload("res://scripts/ui/menu/master_menu_stat_icon.gd")
const MasterMenuTileIconScript := preload("res://scripts/ui/menu/master_menu_tile_icon.gd")
const MasterMenuCreaturePortraitScript := preload("res://scripts/ui/menu/master_menu_creature_portrait.gd")
const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const EquipmentSlotIconScript := preload("res://scripts/ui/inventory/equipment_slot_icon.gd")
const InventorySlotButtonScript := preload("res://scripts/ui/inventory/inventory_slot_button.gd")
const EquipmentSlotButtonScript := preload("res://scripts/ui/inventory/equipment_slot_button.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const SLOT_DRAG_TYPE := "elderforge_inventory_slot"
const EQUIPMENT_DRAG_TYPE := "elderforge_equipment_slot"

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

const INVENTORY_EQUIPMENT_SLOTS := [
	{"id": "bag", "label": "Bag", "abbr": "BG"},
	{"id": "head", "label": "Helmet", "abbr": "HM"},
	{"id": "cape", "label": "Cape", "abbr": "CP"},
	{"id": "main_hand", "label": "Main Hand", "abbr": "MH"},
	{"id": "chest", "label": "Chest", "abbr": "CH"},
	{"id": "off_hand", "label": "Off Hand", "abbr": "OH"},
	{"id": "potion", "label": "Potion", "abbr": "PT"},
	{"id": "shoes", "label": "Shoes", "abbr": "SH"},
	{"id": "food", "label": "Food", "abbr": "FD"},
]
const INVENTORY_ABILITY_SLOT_ORDER := ["q", "w", "e", "r", "d", "f"]

const CATEGORY_NEWS := {
	"glossary": {
		"title": "Recent glossary entries",
		"entries": [
			{"tag": "Creatures", "title": "Lantern Moth"},
			{"tag": "Creatures", "title": "Mineweb Spider"},
			{"tag": "Threat", "title": "Blackroot Stag"},
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

const CREATURE_ENTRY_ORDER := [
	"hollowfield_rat",
	"hearthvale_hare",
	"vale_deer",
	"ashback_boar",
	"lantern_moth",
	"claybank_toad",
	"mineweb_spider",
	"duskfeather_crow",
	"corrupted_wolf",
	"blackroot_stag",
	"silverneedle_needlekin",
]

const CREATURE_DETAIL_ENTRIES := {
	"hollowfield_rat": {
		"label": "Hollowfield Rat",
		"vulnerabilities": ["Steel", "Traps", "Fire"],
		"right_title": "Hollowfield Rat",
		"description": "A lean field rat with pale whiskers and sharp black eyes. Hollowfield rats are ordinary animals, but their nests often mark forgotten grain stores, rotten floorboards, or places where people left in a hurry.\n\nThey make good early skinning and combat targets, and their nests can point toward ruined cellars, food stores, or small scavenger loot.",
	},
	"hearthvale_hare": {
		"label": "Hearthvale Hare",
		"vulnerabilities": ["Traps", "Bows", "Stealth"],
		"right_title": "Hearthvale Hare",
		"description": "A quick brown hare with bright eyes and long ears. It is common enough to hunt, but hard enough to catch that new hunters learn patience before they learn pride.\n\nHearthvale Hares flee toward brush and hedgerows. Quiet approach, simple traps, and bow practice make them useful for the first hunting lessons around Hearthbridge.",
	},
	"vale_deer": {
		"label": "Vale Deer",
		"vulnerabilities": ["Bows", "Traps", "Terrain"],
		"right_title": "Vale Deer",
		"description": "A lean forest deer with warm brown fur and pale throat markings. It listens more than it looks, and by the time most hunters see it clearly, it has already decided where to run.\n\nVale Deer are an early source of Deer Hide II, venison, antler, and sinew. The Verdant Circle teaches that taking one deer is hunting, but scattering the herd is arrogance.",
	},
	"ashback_boar": {
		"label": "Ashback Boar",
		"vulnerabilities": ["Spears", "Sidestep", "Traps"],
		"right_title": "Ashback Boar",
		"description": "A heavy boar with a dark ash-colored stripe down its back and small tusks polished by rooting through clay and stone. It is not evil, but it is very easy to insult.\n\nAshback Boars warn first, charge if approached, and retreat when badly wounded. They teach new players to read enemy wind-up animations before the first real monster fights.",
	},
	"lantern_moth": {
		"label": "Lantern Moth",
		"vulnerabilities": ["Smoke", "Cold", "Covered Light"],
		"right_title": "Lantern Moth",
		"description": "A soft-winged moth with a faint gold glow under its wings. It is harmless, but its dust is useful in weak light potions, trail markers, and beginner warding mixtures.\n\nLantern Moths gather around old lamps, moonleaf patches, shrine stones, and lantern oil spills. Unusual swarms may reveal a hidden shrine, fresh spirit trace, or old path.",
	},
	"claybank_toad": {
		"label": "Claybank Toad",
		"vulnerabilities": ["Nets", "Care", "Clean Water"],
		"right_title": "Claybank Toad",
		"description": "A squat brown toad with clay-colored skin and a pale throat pouch. It croaks before rain and carries a mild toxin useful for early antidote practice.\n\nClaybank Toads live in ditches, river bends, and muddy clay pits. Apothecaries use their glands for weak poison, weak antidotes, and wetland gathering lessons.",
	},
	"mineweb_spider": {
		"label": "Mineweb Spider",
		"vulnerabilities": ["Fire", "Boots", "Range"],
		"right_title": "Mineweb Spider",
		"description": "A low cave spider with gray legs, pale eyes, and sticky webbing stretched between cracked stones. It waits where careless miners put their hands.\n\nMineweb Spiders hide near corners, spit web to slow targets, and retreat toward nests. Burning weak webs is the first lesson most miners learn twice.",
	},
	"duskfeather_crow": {
		"label": "Duskfeather Crow",
		"vulnerabilities": ["Bows", "Bait", "Noise"],
		"right_title": "Duskfeather Crow",
		"description": "A dark crow with blue-black feathers and a sharp voice. It is no monster, but it has an uncomfortable habit of finding trouble before people do.\n\nDuskfeather Crows gather near recent kills, abandoned camps, gallows, and hidden caches. If one watches too long, check whether you are standing on someone else's secret.",
	},
	"corrupted_wolf": {
		"label": "Corrupted Wolf",
		"vulnerabilities": ["Fire", "Steel", "Traps"],
		"right_title": "Corrupted Wolf",
		"description": "A Hearthvale wolf warped by Rift-scarred root corruption. It still hunts like a wolf, but the pack no longer kills only to eat.\n\nCorrupted Wolves circle weak targets, howl to pull nearby packmates, and ignore fear. Blackroot splinters in their fur can point toward a nearby corruption source.",
	},
	"blackroot_stag": {
		"label": "Blackroot Stag",
		"vulnerabilities": ["Fire", "Spears", "Cleansing Oil"],
		"right_title": "Blackroot Stag",
		"description": "A corrupted stag with black antlers and rootlike growths beneath its hide. It moves like a wounded forest trying to gore the thing that hurt it.\n\nBlackroot Stags usually mark a nearby corrupted water source. Their charge is dangerous but predictable, and cleansing the source can prevent future stag corruption.",
	},
	"silverneedle_needlekin": {
		"label": "Silverneedle Needlekin",
		"vulnerabilities": ["Fire", "Steel", "Offerings"],
		"right_title": "Silverneedle Needlekin",
		"description": "A small grove spirit with a bark mask, needle-cloak, and eyes like moonlit sap. It remembers oaths spoken beneath Silverneedle branches and does not forgive wasteful cutting quickly.\n\nNeedlekin are not evil. They attack gatherers who cut too much, cut corrupted trees carelessly, or forget the old rule: take the trunk, leave the cone.",
	},
}

const DETAIL_CONTENT := {
	"creatures": {
		"title": "Creatures",
		"left_title": "Known Creatures",
		"items": ["Hollowfield Rat", "Hearthvale Hare", "Vale Deer", "Ashback Boar", "Lantern Moth", "Claybank Toad", "Mineweb Spider", "Duskfeather Crow", "Corrupted Wolf", "Blackroot Stag", "Silverneedle Needlekin"],
		"selected": "Lantern Moth",
		"creature_id": "lantern_moth",
		"vulnerabilities": ["Smoke", "Cold", "Covered Light"],
		"right_title": "Lantern Moth",
		"description": "A soft-winged moth with a faint gold glow under its wings. It is harmless, but its dust is useful in weak light potions, trail markers, and beginner warding mixtures.\n\nLantern Moths gather around old lamps, moonleaf patches, shrine stones, and lantern oil spills. Unusual swarms may reveal a hidden shrine, fresh spirit trace, or old path.",
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
var _detail_list_scroll_offsets: Dictionary = {}
var _block_world_input_until_mouse_release := false
var _active_category_id := "glossary"
var _active_detail_id := ""
var _selected_creature_id := "lantern_moth"
var _selected_crafting_recipe_id := ""
var _selected_inventory_slot_index := -1
var _selected_inventory_equipment_slot_id := ""
var _selected_inventory_spell_path := ""


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
	for row in _inventory_item_rows(2):
		var row_data := row as Dictionary
		entries.append({
			"tag": String(row_data.get("category", "Item")),
			"title": "%s x%d" % [
				String(row_data.get("name", "Item")),
				int(row_data.get("quantity", 1)),
			],
		})

	var silver := _inventory_silver()
	if silver > 0:
		entries.append({
			"tag": "Currency",
			"title": "%s silver carried" % _format_whole_number(silver),
		})

	if entries.is_empty():
		entries.append({
			"tag": "Bag",
			"title": "Inventory is empty",
		})

	return {
		"title": "Current inventory",
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
	elif _active_detail_id == "inventory":
		_build_inventory_detail(data)
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


func _build_inventory_detail(_data: Dictionary) -> void:
	_ensure_inventory_selection()
	_detail_body.add_child(_build_inventory_bag_panel())
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_inventory_equipment_panel())
	_detail_body.add_child(_build_detail_column_spacer())
	_detail_body.add_child(_build_inventory_inspector_panel())


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
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 7)
	panel.add_child(_wrap_margin(layout, 8))

	var title := Label.new()
	title.text = String(data.get("left_title", "Entries")).to_upper()
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "EntryScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var item_list := VBoxContainer.new()
	item_list.name = "EntryList"
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 7)
	scroll.add_child(item_list)

	var items := data.get("items", []) as Array
	var selected := String(data.get("selected", ""))
	for item in items:
		var item_data := _detail_item_data(item)
		var item_label := String(item_data.get("label", "Entry"))
		var item_id := String(item_data.get("id", item_label))
		item_list.add_child(_build_detail_list_item(item_label, item_label == selected, item_id))
	return panel


func _build_detail_list_item(label_text: String, is_selected: bool, item_id: String) -> Control:
	var button := Button.new()
	button.text = label_text
	button.tooltip_text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14 if is_selected else 13)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_detail_item_style(is_selected))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_detail_item_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_detail_item_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_constant_override("h_separation", 0)
	button.pressed.connect(_on_detail_list_item_pressed.bind(item_id))
	return button


func _build_inventory_bag_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InventoryBagPanel"
	panel.custom_minimum_size = Vector2(405.0, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(_wrap_margin(layout, 10))

	var title := Label.new()
	title.text = "BAG CONTENTS"
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var summary := Label.new()
	summary.name = "BagSummary"
	summary.text = "%d / %d slots used" % [_inventory_slots_used(), _inventory_slot_total()]
	UiStyle.label_muted(summary, 12)
	layout.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.name = "BagScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "BagSlotGrid"
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(grid)

	var total_slots := maxi(_inventory_slot_total(), _inventory_display_slots().size())
	for slot_index in range(total_slots):
		grid.add_child(_build_inventory_bag_slot(slot_index))

	if total_slots <= 0:
		var empty_label := Label.new()
		empty_label.text = "No inventory is bound."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.label_muted(empty_label, 14)
		grid.add_child(empty_label)

	return panel


func _build_inventory_bag_slot(slot_index: int) -> Control:
	var slot_data := _inventory_slot_at(slot_index)
	var is_selected := (
		_selected_inventory_equipment_slot_id.is_empty()
		and _selected_inventory_slot_index == slot_index
	)

	var button: Button = InventorySlotButtonScript.new()
	button.name = "BagSlot%02d" % (slot_index + 1)
	button.custom_minimum_size = Vector2(48.0, 48.0)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = ""
	button.tooltip_text = _inventory_slot_tooltip(slot_index, slot_data)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.call("setup", self, slot_index)
	button.pressed.connect(_on_inventory_bag_slot_pressed.bind(slot_index))

	if slot_data.is_empty():
		button.add_theme_stylebox_override("normal", _inventory_slot_style(Color(0.08, 0.09, 0.08, 1.0), false, is_selected))
		button.add_theme_stylebox_override("hover", _inventory_slot_style(Color(0.13, 0.14, 0.12, 1.0), true, is_selected))
		button.add_theme_stylebox_override("pressed", _inventory_slot_style(Color(0.06, 0.07, 0.06, 1.0), true, is_selected))
		return button

	var item_icon := InventoryItemIconScript.new() as Control
	item_icon.name = "ItemIcon"
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.call("set_item", slot_data)
	button.add_child(item_icon)

	var item_color := slot_data.get("color", Color(0.28, 0.32, 0.28, 1.0)) as Color
	button.add_theme_stylebox_override("normal", _inventory_slot_style(item_color.darkened(0.38), false, is_selected))
	button.add_theme_stylebox_override("hover", _inventory_slot_style(item_color.darkened(0.22), true, is_selected))
	button.add_theme_stylebox_override("pressed", _inventory_slot_style(item_color.darkened(0.48), true, is_selected))
	return button


func _build_inventory_equipment_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InventoryEquipmentPanel"
	panel.custom_minimum_size = Vector2(280.0, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(_wrap_margin(layout, 10))

	var title := Label.new()
	title.text = "EQUIPPED GEAR"
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var grid := GridContainer.new()
	grid.name = "EquipmentSlotGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	layout.add_child(grid)

	for definition in INVENTORY_EQUIPMENT_SLOTS:
		grid.add_child(_build_inventory_equipment_slot(definition as Dictionary))

	var readouts := VBoxContainer.new()
	readouts.name = "InventoryReadouts"
	readouts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readouts.add_theme_constant_override("separation", 6)
	layout.add_child(readouts)
	readouts.add_child(_build_inventory_readout("Weight", "%s / %s kg" % [
		_format_decimal(_inventory_carried_weight()),
		_format_decimal(_inventory_max_load()),
	]))
	readouts.add_child(_build_inventory_readout("Silver", _format_whole_number(_inventory_silver())))
	var gold := _inventory_gold()
	if gold > 0:
		readouts.add_child(_build_inventory_readout("Gold", _format_whole_number(gold)))

	return panel


func _build_inventory_equipment_slot(definition: Dictionary) -> Control:
	var slot_id := String(definition.get("id", ""))
	var label_text := String(definition.get("label", _format_slot_label(slot_id)))
	var slot_data := _inventory_equipped_slot_at(slot_id)
	var is_selected := _selected_inventory_equipment_slot_id == slot_id

	var cell := VBoxContainer.new()
	cell.name = "%sEquipmentCell" % slot_id.capitalize().replace(" ", "")
	cell.custom_minimum_size = Vector2(82.0, 78.0)
	cell.add_theme_constant_override("separation", 3)

	var button: Button = EquipmentSlotButtonScript.new()
	button.name = "%sEquipmentSlot" % slot_id.capitalize().replace(" ", "")
	button.custom_minimum_size = Vector2(58.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = ""
	button.tooltip_text = "%s: %s" % [label_text, _slot_display_name(slot_data)] if not slot_data.is_empty() else label_text
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.call("setup", self, slot_id)
	button.pressed.connect(_on_inventory_equipment_slot_pressed.bind(slot_id))
	cell.add_child(button)

	if slot_data.is_empty():
		var empty_icon := EquipmentSlotIconScript.new() as Control
		empty_icon.name = "DefaultIcon"
		empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_icon.offset_left = 7.0
		empty_icon.offset_top = 7.0
		empty_icon.offset_right = -7.0
		empty_icon.offset_bottom = -7.0
		empty_icon.call("set_icon_id", slot_id)
		button.add_child(empty_icon)
		button.add_theme_stylebox_override("normal", _inventory_slot_style(Color(0.08, 0.09, 0.08, 1.0), false, is_selected))
		button.add_theme_stylebox_override("hover", _inventory_slot_style(Color(0.13, 0.14, 0.12, 1.0), true, is_selected))
		button.add_theme_stylebox_override("pressed", _inventory_slot_style(Color(0.06, 0.07, 0.06, 1.0), true, is_selected))
	else:
		var item_icon := InventoryItemIconScript.new() as Control
		item_icon.name = "ItemIcon"
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_icon.call("set_item", slot_data)
		button.add_child(item_icon)

		var item_color := slot_data.get("color", Color(0.28, 0.32, 0.28, 1.0)) as Color
		button.add_theme_stylebox_override("normal", _inventory_slot_style(item_color.darkened(0.38), false, is_selected))
		button.add_theme_stylebox_override("hover", _inventory_slot_style(item_color.darkened(0.22), true, is_selected))
		button.add_theme_stylebox_override("pressed", _inventory_slot_style(item_color.darkened(0.48), true, is_selected))

	var label := Label.new()
	label.text = String(definition.get("abbr", label_text.substr(0, 2))).to_upper()
	label.tooltip_text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(label, 10)
	cell.add_child(label)
	return cell


func _build_inventory_readout(label_text: String, value_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%sReadout" % label_text.replace(" ", "")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_item_style(false))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	panel.add_child(_wrap_margin(row, 7))

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_muted(label, 12)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(96.0, 0.0)
	UiStyle.label_primary(value, 12, 1)
	row.add_child(value)
	return panel


func _build_inventory_inspector_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InventoryInspectorPanel"
	panel.custom_minimum_size = Vector2(300.0, 430.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(_wrap_margin(layout, 12))

	var selected_data := _selected_inventory_item_data()
	var selected_title := _selected_inventory_title(selected_data)

	var title := Label.new()
	title.text = "SPELL LOADOUT"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_primary(title, 16, 1)
	layout.add_child(title)

	var item_label := Label.new()
	item_label.name = "SpellLoadoutItemName"
	item_label.text = selected_title
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_muted(item_label, 12)
	layout.add_child(item_label)

	var choice_rows := _inventory_spell_choice_rows(selected_data)
	_ensure_inventory_spell_focus(choice_rows)
	if choice_rows.is_empty():
		var empty_label := Label.new()
		empty_label.name = "SpellLoadoutEmpty"
		empty_label.text = (
			"No active spells available."
			if not selected_data.is_empty()
			else "No spell loadout selected."
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiStyle.label_muted(empty_label, 13)
		layout.add_child(empty_label)
		return panel

	var scroll := ScrollContainer.new()
	scroll.name = "SpellLoadoutScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "SpellLoadoutList"
	content.custom_minimum_size = Vector2(270.0, 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)

	var item_id := String(selected_data.get("id", "")).strip_edges()
	for row_value in choice_rows:
		var row := row_value as Dictionary
		var slot_id := String(row.get("slot_id", ""))

		var slot_label := Label.new()
		slot_label.text = "%s SPELL" % slot_id.to_upper()
		UiStyle.label_primary(slot_label, 12, 1)
		content.add_child(slot_label)

		var paths := PackedStringArray(row.get("paths", PackedStringArray()))
		var selected_path := String(row.get("selected_path", ""))
		for choice_index in range(paths.size()):
			content.add_child(_build_inventory_spell_choice_button(
				item_id,
				slot_id,
				paths[choice_index],
				paths[choice_index] == selected_path,
				choice_index
			))

	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 5)
	content.add_child(separator)

	var focused_definition := _load_inventory_ability(_selected_inventory_spell_path)
	if focused_definition == null:
		return panel

	var spell_title := Label.new()
	spell_title.name = "SelectedSpellTitle"
	spell_title.text = String(focused_definition.get("display_name"))
	spell_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_primary(spell_title, 15, 1)
	content.add_child(spell_title)

	var description := Label.new()
	description.name = "SelectedSpellDescription"
	description.text = String(focused_definition.get("description"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_muted(description, 13)
	content.add_child(description)

	var raw_effects: Variant = focused_definition.get("tooltip_effects")
	if raw_effects is Array:
		for effect_value in raw_effects as Array:
			var effect := effect_value as Resource
			if effect == null:
				continue
			content.add_child(_build_inventory_spell_detail_row(
				String(effect.get("label")),
				String(effect.get("value"))
			))

	content.add_child(_build_inventory_spell_detail_row(
		"Energy",
		_format_decimal(float(focused_definition.get("energy_cost")))
	))
	content.add_child(_build_inventory_spell_detail_row(
		"Cooldown",
		"%ss" % _format_decimal(float(focused_definition.get("cooldown_seconds")))
	))
	content.add_child(_build_inventory_spell_detail_row(
		"Cast",
		"%ss" % _format_decimal(float(focused_definition.get("cast_duration_seconds")))
	))
	return panel


func _build_inventory_spell_choice_button(
	item_id: String,
	slot_id: String,
	ability_path: String,
	is_selected: bool,
	choice_index: int
) -> Button:
	var definition := _load_inventory_ability(ability_path)
	var display_name := (
		String(definition.get("display_name"))
		if definition != null
		else ability_path.get_file().get_basename().capitalize()
	)

	var button := Button.new()
	button.name = "SpellChoice%s%02d" % [slot_id.to_upper(), choice_index + 1]
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.text = "%s%s" % [display_name, "  SELECTED" if is_selected else ""]
	button.tooltip_text = String(definition.get("description")) if definition != null else display_name
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_detail_item_style(is_selected))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_detail_item_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_detail_item_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.set_meta("ability_path", ability_path)
	button.set_meta("ability_slot_id", slot_id)
	button.pressed.connect(_on_inventory_spell_choice_pressed.bind(
		item_id,
		slot_id,
		ability_path
	))
	return button


func _build_inventory_spell_detail_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72.0, 0.0)
	UiStyle.label_muted(label, 11)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.label_primary(value, 11, 1)
	row.add_child(value)
	return row


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
	portrait.set("creature_id", String(data.get("creature_id", "needlekin")))
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
	var vulnerabilities := data.get("vulnerabilities", ["Fire", "Steel"]) as Array
	for raw_vulnerability in vulnerabilities:
		badges.add_child(_build_vulnerability_badge(String(raw_vulnerability).to_upper()))
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

	if data.has("ingredients"):
		_populate_ingredients_center_panel(layout, data)
		return panel

	var icon := MasterMenuTileIconScript.new() as Control
	icon.custom_minimum_size = Vector2(78.0, 78.0)
	icon.set("icon_id", _active_detail_id)
	layout.add_child(icon)

	var title := Label.new()
	title.text = String(data.get("center_title", data.get("selected", _detail_label(_active_detail_id)))).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 20, 2)
	layout.add_child(title)

	var hint := Label.new()
	hint.text = String(data.get("center_hint", "PAGE PREVIEW")).to_upper()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(hint, 12)
	layout.add_child(hint)
	return panel


func _populate_ingredients_center_panel(layout: VBoxContainer, data: Dictionary) -> void:
	var icon := MasterMenuTileIconScript.new() as Control
	icon.custom_minimum_size = Vector2(54.0, 54.0)
	icon.set("icon_id", "crafting")
	layout.add_child(icon)

	var title := Label.new()
	title.text = String(data.get("center_title", "Ingredients")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 18, 2)
	layout.add_child(title)

	var station := Label.new()
	station.text = String(data.get("center_hint", "Crafting Station")).to_upper()
	station.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(station, 11)
	layout.add_child(station)

	var output := Label.new()
	output.text = "MAKES: %s" % String(data.get("output_text", "Selected item")).to_upper()
	output.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.label_muted(output, 11)
	output.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	layout.add_child(output)

	var ingredient_list := VBoxContainer.new()
	ingredient_list.name = "IngredientList"
	ingredient_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ingredient_list.add_theme_constant_override("separation", 7)
	layout.add_child(ingredient_list)

	var ingredients := data.get("ingredients", []) as Array
	if ingredients.is_empty():
		ingredient_list.add_child(_build_ingredient_row("No ingredients listed", 0))
		return

	for ingredient in ingredients:
		var ingredient_data := ingredient as Dictionary
		ingredient_list.add_child(_build_ingredient_row(
			String(ingredient_data.get("name", "Item")),
			int(ingredient_data.get("quantity", 1))
		))


func _build_ingredient_row(item_name: String, quantity: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_item_style(false))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	panel.add_child(_wrap_margin(row, 8))

	var name_label := Label.new()
	name_label.text = item_name
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.label_primary(name_label, 12, 1)
	row.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = "x%d" % maxi(quantity, 0) if quantity > 0 else ""
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.custom_minimum_size = Vector2(42.0, 0.0)
	UiStyle.label_muted(quantity_label, 12)
	quantity_label.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	row.add_child(quantity_label)
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

	if _inventory.has_signal("equipped_slots_changed"):
		var equipped_callable := Callable(self, "_on_inventory_equipment_changed")
		if not _inventory.is_connected("equipped_slots_changed", equipped_callable):
			_inventory.connect("equipped_slots_changed", equipped_callable)

	if _inventory.has_signal("ability_selection_changed"):
		var selection_callable := Callable(self, "_on_inventory_ability_selection_changed")
		if not _inventory.is_connected("ability_selection_changed", selection_callable):
			_inventory.connect("ability_selection_changed", selection_callable)


func _disconnect_inventory_signals() -> void:
	if _inventory == null:
		return

	var slots_callable := Callable(self, "_on_inventory_slots_changed")
	if _inventory.has_signal("slots_changed") and _inventory.is_connected("slots_changed", slots_callable):
		_inventory.disconnect("slots_changed", slots_callable)

	var currency_callable := Callable(self, "_on_inventory_currency_changed")
	if _inventory.has_signal("currency_changed") and _inventory.is_connected("currency_changed", currency_callable):
		_inventory.disconnect("currency_changed", currency_callable)

	var equipped_callable := Callable(self, "_on_inventory_equipment_changed")
	if _inventory.has_signal("equipped_slots_changed") and _inventory.is_connected("equipped_slots_changed", equipped_callable):
		_inventory.disconnect("equipped_slots_changed", equipped_callable)

	var selection_callable := Callable(self, "_on_inventory_ability_selection_changed")
	if (
		_inventory.has_signal("ability_selection_changed")
		and _inventory.is_connected("ability_selection_changed", selection_callable)
	):
		_inventory.disconnect("ability_selection_changed", selection_callable)


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
	_refresh_live_inventory_views()


func _on_inventory_currency_changed(_silver: int, _gold: int) -> void:
	_refresh_inventory_summary()
	_refresh_live_inventory_views()


func _on_inventory_equipment_changed() -> void:
	_refresh_live_inventory_views()


func _on_inventory_ability_selection_changed(
	_item_id: String,
	_slot_id: String,
	_ability_path: String
) -> void:
	_refresh_live_inventory_views()


func _on_player_stat_changed(_stat_id: StringName, _value: float) -> void:
	_refresh_inventory_summary()
	if _active_detail_id == "character":
		_update_detail_view()


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


func _inventory_gold() -> int:
	if _inventory != null and _inventory.has_method("get_gold"):
		return maxi(int(_inventory.call("get_gold")), 0)

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


func _refresh_live_inventory_views() -> void:
	if _active_category_id == "inventory":
		_refresh_news_panel()
	if _active_detail_id == "inventory":
		_update_detail_view()


func _inventory_display_slots() -> Array:
	if _inventory == null or not _inventory.has_method("get_display_slots"):
		return []

	var slots: Variant = _inventory.call("get_display_slots")
	return slots if slots is Array else []


func _inventory_slot_at(slot_index: int) -> Dictionary:
	var slots := _inventory_display_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return {}

	var slot_data := slots[slot_index] as Dictionary
	return slot_data if slot_data != null else {}


func _inventory_equipped_slots() -> Dictionary:
	if _inventory == null or not _inventory.has_method("get_equipped_slots"):
		return {}

	var equipped_value: Variant = _inventory.call("get_equipped_slots")
	return equipped_value if equipped_value is Dictionary else {}


func _inventory_equipped_slot_at(slot_id: String) -> Dictionary:
	var equipped := _inventory_equipped_slots()
	var slot_data := equipped.get(slot_id, {}) as Dictionary
	return slot_data if slot_data != null else {}


func _ensure_inventory_selection() -> void:
	var total_slots := maxi(_inventory_slot_total(), _inventory_display_slots().size())
	if (
		_selected_inventory_equipment_slot_id.is_empty()
		and _selected_inventory_slot_index >= 0
		and _selected_inventory_slot_index < total_slots
	):
		return

	if not _selected_inventory_equipment_slot_id.is_empty():
		for definition in INVENTORY_EQUIPMENT_SLOTS:
			if String((definition as Dictionary).get("id", "")) == _selected_inventory_equipment_slot_id:
				return

	_selected_inventory_slot_index = -1
	_selected_inventory_equipment_slot_id = ""

	for slot_index in range(total_slots):
		if not _inventory_slot_at(slot_index).is_empty():
			_selected_inventory_slot_index = slot_index
			return

	for definition in INVENTORY_EQUIPMENT_SLOTS:
		var slot_id := String((definition as Dictionary).get("id", ""))
		if not _inventory_equipped_slot_at(slot_id).is_empty():
			_selected_inventory_equipment_slot_id = slot_id
			return

	if total_slots > 0:
		_selected_inventory_slot_index = 0


func _on_inventory_bag_slot_pressed(slot_index: int) -> void:
	_selected_inventory_slot_index = slot_index
	_selected_inventory_equipment_slot_id = ""
	_selected_inventory_spell_path = ""
	_update_detail_view()


func _on_inventory_equipment_slot_pressed(slot_id: String) -> void:
	_selected_inventory_slot_index = -1
	_selected_inventory_equipment_slot_id = slot_id
	_selected_inventory_spell_path = ""
	_update_detail_view()


## Returns drag payload for a filled fullscreen bag slot.
func get_slot_drag_data(slot_index: int) -> Variant:
	if _inventory_slot_at(slot_index).is_empty():
		return null

	return {
		"type": SLOT_DRAG_TYPE,
		"source_index": slot_index,
	}


func create_slot_drag_preview(slot_index: int) -> Control:
	return _create_inventory_drag_preview(_inventory_slot_at(slot_index), "DraggedBagItemIcon")


func can_drop_slot_data(target_index: int, data: Variant) -> bool:
	if _inventory == null or typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_data := data as Dictionary
	if String(drag_data.get("type", "")) != EQUIPMENT_DRAG_TYPE:
		return false

	var source_slot_id := String(drag_data.get("source_slot_id", ""))
	return (
		_inventory.has_method("can_unequip_to_slot")
		and bool(_inventory.call("can_unequip_to_slot", source_slot_id, target_index))
	)


func drop_slot_data(target_index: int, data: Variant) -> void:
	if not can_drop_slot_data(target_index, data):
		return

	var source_slot_id := String((data as Dictionary).get("source_slot_id", ""))
	_selected_inventory_slot_index = target_index
	_selected_inventory_equipment_slot_id = ""
	if not bool(_inventory.call("unequip_to_slot", source_slot_id, target_index)):
		_selected_inventory_slot_index = -1
		_selected_inventory_equipment_slot_id = source_slot_id
		return

	_update_detail_view()


## Returns drag payload for a filled fullscreen equipment slot.
func get_gear_slot_drag_data(slot_id: String) -> Variant:
	if _inventory_equipped_slot_at(slot_id).is_empty():
		return null

	return {
		"type": EQUIPMENT_DRAG_TYPE,
		"source_slot_id": slot_id,
	}


func create_gear_slot_drag_preview(slot_id: String) -> Control:
	return _create_inventory_drag_preview(_inventory_equipped_slot_at(slot_id), "DraggedGearIcon")


func can_drop_gear_slot_data(slot_id: String, data: Variant) -> bool:
	if _inventory == null or slot_id.is_empty() or typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_data := data as Dictionary
	if String(drag_data.get("type", "")) != SLOT_DRAG_TYPE:
		return false

	var source_index := int(drag_data.get("source_index", -1))
	return (
		_inventory.has_method("can_equip_from_slot")
		and bool(_inventory.call("can_equip_from_slot", source_index, slot_id))
	)


func drop_gear_slot_data(slot_id: String, data: Variant) -> void:
	if not can_drop_gear_slot_data(slot_id, data):
		return

	var source_index := int((data as Dictionary).get("source_index", -1))
	_selected_inventory_slot_index = -1
	_selected_inventory_equipment_slot_id = slot_id
	if not bool(_inventory.call("equip_from_slot", source_index, slot_id)):
		_selected_inventory_slot_index = source_index
		_selected_inventory_equipment_slot_id = ""
		return

	_update_detail_view()


func _create_inventory_drag_preview(slot_data: Dictionary, icon_name: String) -> Control:
	if slot_data.is_empty():
		return null

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.size = Vector2(64.0, 64.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.88)

	var item_icon := InventoryItemIconScript.new() as Control
	item_icon.name = icon_name
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.call("set_item", slot_data)
	preview.add_child(item_icon)
	return preview


func _inventory_slot_tooltip(slot_index: int, slot_data: Dictionary) -> String:
	if slot_data.is_empty():
		return "Bag Slot %d" % (slot_index + 1)

	return "%s x%d" % [
		_slot_display_name(slot_data),
		maxi(int(slot_data.get("quantity", 1)), 1),
	]


func _inventory_item_rows(limit: int = 0) -> Array:
	var totals := {}
	var ordered_ids: Array[String] = []
	for slot in _inventory_display_slots():
		var slot_data := slot as Dictionary
		if slot_data == null or slot_data.is_empty():
			continue

		var item_id := String(slot_data.get("id", slot_data.get("item_id", ""))).strip_edges()
		if item_id.is_empty():
			item_id = _fallback_item_id(slot_data)
		if item_id.is_empty():
			continue

		if not totals.has(item_id):
			ordered_ids.append(item_id)
			totals[item_id] = {
				"name": _slot_display_name(slot_data),
				"category": String(slot_data.get("category", "Item")),
				"quantity": 0,
				"tier": int(slot_data.get("tier", 0)),
				"tier_roman": String(slot_data.get("tier_roman", "")),
				"unit_weight": float(slot_data.get("unit_weight", 0.0)),
				"description": String(slot_data.get("description", "")),
			}

		var row := totals[item_id] as Dictionary
		row["quantity"] = int(row.get("quantity", 0)) + int(slot_data.get("quantity", 1))

	var rows: Array = []
	for item_id in ordered_ids:
		rows.append(totals[item_id])
		if limit > 0 and rows.size() >= limit:
			break

	return rows


func _inventory_equipped_rows() -> Array:
	var equipped := _inventory_equipped_slots()
	var rows: Array = []
	var slot_order := [
		"bag",
		"head",
		"cape",
		"main_hand",
		"chest",
		"off_hand",
		"potion",
		"shoes",
		"food",
	]
	var consumed := {}
	for slot_id in slot_order:
		if not equipped.has(slot_id):
			continue
		consumed[slot_id] = true
		_append_equipped_row(rows, slot_id, equipped[slot_id])

	for slot_id in equipped.keys():
		var slot_key := String(slot_id)
		if consumed.has(slot_key):
			continue
		_append_equipped_row(rows, slot_key, equipped[slot_id])

	return rows


func _append_equipped_row(rows: Array, slot_id: String, slot_value: Variant) -> void:
	var slot_data := slot_value as Dictionary
	if slot_data == null or slot_data.is_empty():
		return

	rows.append({
		"slot": _equipment_slot_label(slot_id),
		"name": _slot_display_name(slot_data),
		"category": String(slot_data.get("category", "Gear")),
	})


func _inventory_detail_content() -> Dictionary:
	var item_rows := _inventory_item_rows(12)
	var list_items: Array[String] = []
	for row in item_rows:
		list_items.append(_format_inventory_item_row(row as Dictionary))
	if list_items.is_empty():
		list_items.append("Empty Bag")

	return {
		"title": "Inventory",
		"left_title": "Bag Contents",
		"items": list_items,
		"selected": list_items[0],
		"center_title": "%d / %d slots" % [_inventory_slots_used(), _inventory_slot_total()],
		"center_hint": "%s / %s kg" % [
			_format_decimal(_inventory_carried_weight()),
			_format_decimal(_inventory_max_load()),
		],
		"right_title": "Inventory Overview",
		"description": _inventory_detail_description(item_rows),
	}


func _inventory_detail_description(item_rows: Array) -> String:
	var lines := PackedStringArray()
	lines.append("Slots used: %d / %d" % [_inventory_slots_used(), _inventory_slot_total()])
	lines.append("Weight: %s / %s kg" % [_format_decimal(_inventory_carried_weight()), _format_decimal(_inventory_max_load())])
	lines.append("Silver: %s" % _format_whole_number(_inventory_silver()))
	var gold := _inventory_gold()
	if gold > 0:
		lines.append("Gold: %s" % _format_whole_number(gold))

	var equipped_rows := _inventory_equipped_rows()
	if not equipped_rows.is_empty():
		lines.append("")
		lines.append("Equipped")
		for row in equipped_rows.slice(0, 5):
			var row_data := row as Dictionary
			lines.append("%s: %s" % [String(row_data.get("slot", "Slot")), String(row_data.get("name", "Item"))])

	lines.append("")
	if item_rows.is_empty():
		lines.append("Bag is empty.")
	else:
		lines.append("Bag Contents")
		for row in item_rows.slice(0, 8):
			lines.append(_format_inventory_item_row(row as Dictionary))

	return "\n".join(lines)


func _format_inventory_item_row(row: Dictionary) -> String:
	var quantity := maxi(int(row.get("quantity", 1)), 1)
	var tier_roman := String(row.get("tier_roman", "")).strip_edges()
	var prefix := "T%s " % tier_roman if not tier_roman.is_empty() else ""
	return "%s%s x%d" % [prefix, String(row.get("name", "Item")), quantity]


func _selected_inventory_item_data() -> Dictionary:
	if not _selected_inventory_equipment_slot_id.is_empty():
		return _inventory_equipped_slot_at(_selected_inventory_equipment_slot_id)

	return _inventory_slot_at(_selected_inventory_slot_index)


func _selected_inventory_title(selected_data: Dictionary) -> String:
	if not selected_data.is_empty():
		return _slot_display_name(selected_data)

	if not _selected_inventory_equipment_slot_id.is_empty():
		return "Empty %s" % _equipment_slot_label(_selected_inventory_equipment_slot_id)
	if _selected_inventory_slot_index >= 0:
		return "Empty Bag Slot"
	if _inventory == null:
		return "Inventory Unavailable"
	return "Inventory Overview"


func _selected_inventory_meta_rows(selected_data: Dictionary) -> Array:
	var rows: Array = []
	if selected_data.is_empty():
		rows.append({
			"label": "Slots",
			"value": "%d / %d" % [_inventory_slots_used(), _inventory_slot_total()],
		})
		rows.append({
			"label": "Weight",
			"value": "%s / %s kg" % [
				_format_decimal(_inventory_carried_weight()),
				_format_decimal(_inventory_max_load()),
			],
		})
		rows.append({
			"label": "Silver",
			"value": _format_whole_number(_inventory_silver()),
		})
		return rows

	rows.append({
		"label": "Type",
		"value": String(selected_data.get("category", "Item")),
	})

	var quantity := maxi(int(selected_data.get("quantity", 1)), 1)
	var max_stack := maxi(int(selected_data.get("max_stack", 1)), 1)
	rows.append({
		"label": "Stack",
		"value": "%d / %d" % [quantity, max_stack],
	})

	var unit_weight := float(selected_data.get("unit_weight", 0.0))
	if unit_weight > 0.0:
		rows.append({
			"label": "Weight",
			"value": "%s kg" % _format_decimal(unit_weight * float(quantity)),
		})

	var equip_slot := String(selected_data.get("equip_slot", "")).strip_edges()
	if not equip_slot.is_empty():
		rows.append({
			"label": "Slot",
			"value": _equipment_slot_label(equip_slot),
		})

	var ability_slots := _inventory_ability_slot_text(selected_data)
	if not ability_slots.is_empty():
		rows.append({
			"label": "Spells",
			"value": ability_slots,
		})

	return rows


func _selected_inventory_description(selected_data: Dictionary) -> String:
	if not selected_data.is_empty():
		var description := String(selected_data.get("description", "")).strip_edges()
		if not description.is_empty():
			return description
		return "%s is ready to use." % _slot_display_name(selected_data)

	if _inventory == null:
		return "No PlayerInventory node is bound to this menu."

	if not _selected_inventory_equipment_slot_id.is_empty():
		return "Nothing is equipped in the %s slot." % _equipment_slot_label(_selected_inventory_equipment_slot_id)
	if _selected_inventory_slot_index >= 0:
		return "This bag slot is empty."

	return _inventory_detail_description(_inventory_item_rows(12))


func _inventory_spell_choice_rows(slot_data: Dictionary) -> Array:
	var choices := slot_data.get("ability_choices", {}) as Dictionary
	if choices == null or choices.is_empty():
		return []

	var selected_paths := slot_data.get("ability_paths", {}) as Dictionary
	var rows: Array = []
	var consumed := {}
	for slot_id in INVENTORY_ABILITY_SLOT_ORDER:
		if not choices.has(slot_id):
			continue
		consumed[slot_id] = true
		_append_inventory_spell_choice_row(rows, slot_id, choices[slot_id], selected_paths)

	var remaining_slots: Array[String] = []
	for raw_slot_id in choices.keys():
		var slot_id := String(raw_slot_id).strip_edges().to_lower()
		if not slot_id.is_empty() and not consumed.has(slot_id):
			remaining_slots.append(slot_id)
	remaining_slots.sort()
	for slot_id in remaining_slots:
		_append_inventory_spell_choice_row(rows, slot_id, choices[slot_id], selected_paths)
	return rows


func _append_inventory_spell_choice_row(
	rows: Array,
	slot_id: String,
	raw_paths: Variant,
	selected_paths: Dictionary
) -> void:
	var paths := PackedStringArray()
	if raw_paths is PackedStringArray:
		paths = (raw_paths as PackedStringArray).duplicate()
	elif raw_paths is Array:
		for raw_path in raw_paths as Array:
			var path := String(raw_path).strip_edges()
			if not path.is_empty() and not paths.has(path):
				paths.append(path)
	else:
		var path := String(raw_paths).strip_edges()
		if not path.is_empty():
			paths.append(path)
	if paths.is_empty():
		return

	var selected_path := String(selected_paths.get(slot_id, ""))
	if not paths.has(selected_path):
		selected_path = paths[0]
	rows.append({
		"slot_id": slot_id,
		"paths": paths,
		"selected_path": selected_path,
	})


func _ensure_inventory_spell_focus(choice_rows: Array) -> void:
	var available_paths := PackedStringArray()
	var first_selected_path := ""
	for row_value in choice_rows:
		var row := row_value as Dictionary
		var selected_path := String(row.get("selected_path", ""))
		if first_selected_path.is_empty() and not selected_path.is_empty():
			first_selected_path = selected_path
		for path in PackedStringArray(row.get("paths", PackedStringArray())):
			if not available_paths.has(path):
				available_paths.append(path)

	if available_paths.has(_selected_inventory_spell_path):
		return
	_selected_inventory_spell_path = (
		first_selected_path
		if not first_selected_path.is_empty()
		else (available_paths[0] if not available_paths.is_empty() else "")
	)


func _load_inventory_ability(ability_path: String) -> Resource:
	if ability_path.is_empty() or not ResourceLoader.exists(ability_path):
		return null
	return load(ability_path) as Resource


func _on_inventory_spell_choice_pressed(
	item_id: String,
	slot_id: String,
	ability_path: String
) -> void:
	if _inventory == null or not _inventory.has_method("select_item_ability"):
		return

	var previous_path := _selected_inventory_spell_path
	_selected_inventory_spell_path = ability_path
	if not bool(_inventory.call("select_item_ability", item_id, slot_id, ability_path)):
		_selected_inventory_spell_path = previous_path
		return
	_update_detail_view()


func _inventory_ability_slot_text(slot_data: Dictionary) -> String:
	var ability_paths := slot_data.get("ability_paths", {}) as Dictionary
	if ability_paths == null or ability_paths.is_empty():
		return ""

	var slots := PackedStringArray()
	for raw_slot_id in ability_paths.keys():
		var slot_id := String(raw_slot_id).strip_edges().to_upper()
		if not slot_id.is_empty():
			slots.append(slot_id)
	slots.sort()
	return ", ".join(slots)


func _equipment_slot_label(slot_id: String) -> String:
	for definition in INVENTORY_EQUIPMENT_SLOTS:
		var definition_data := definition as Dictionary
		if String(definition_data.get("id", "")) == slot_id:
			return String(definition_data.get("label", _format_slot_label(slot_id)))

	return _format_slot_label(slot_id)


func _inventory_slot_style(background: Color, is_hovered: bool, is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.86, 0.72, 0.25, 1.0) if is_selected else Color(0.31, 0.34, 0.28, 1.0)
	if is_hovered and not is_selected:
		style.border_color = Color(0.58, 0.62, 0.48, 1.0)
	style.set_border_width_all(2 if is_selected else 1)
	style.set_corner_radius_all(6)
	return style


func _slot_display_name(slot_data: Dictionary) -> String:
	var display_name := String(slot_data.get("name", "")).strip_edges()
	if display_name.is_empty():
		display_name = String(slot_data.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = _prettify_id(String(slot_data.get("id", slot_data.get("item_id", "Item"))))
	return display_name


func _fallback_item_id(slot_data: Dictionary) -> String:
	return "%s:%s:%s" % [
		String(slot_data.get("category", "Item")),
		_slot_display_name(slot_data),
		String(slot_data.get("tier", 0)),
	]


func _format_slot_label(slot_id: String) -> String:
	return slot_id.replace("_", " ").capitalize()


func _prettify_id(value: String) -> String:
	var cleaned := value.strip_edges().replace("_", " ")
	return cleaned.capitalize() if not cleaned.is_empty() else "Item"


func _character_detail_content() -> Dictionary:
	var key_stats := _character_key_stat_rows()
	var list_items: Array[String] = []
	for row in key_stats:
		var row_data := row as Dictionary
		list_items.append("%s: %s" % [String(row_data.get("name", "Stat")), String(row_data.get("value", "0"))])
	if list_items.is_empty():
		list_items.append("Stats unavailable")

	return {
		"title": "Character",
		"left_title": "Core Stats",
		"items": list_items,
		"selected": list_items[0],
		"center_title": "Level %d" % maxi(player_level, 1),
		"center_hint": "%d/%d" % [clampi(level_progress_current, 0, maxi(level_progress_required, 1)), maxi(level_progress_required, 1)],
		"right_title": "Character Overview",
		"description": _character_detail_description(key_stats),
	}


func _character_key_stat_rows() -> Array:
	if _stats == null or not _stats.has_method("get_stat"):
		return []

	var key_stat_ids := [
		&"max_health",
		&"health_regeneration",
		&"max_energy",
		&"energy_regeneration",
		&"auto_attack_damage",
		&"auto_attack_speed",
		&"move_speed",
		&"max_load",
	]
	var rows: Array = []
	for stat_id in key_stat_ids:
		rows.append({
			"name": _stat_display_name(stat_id),
			"value": _format_stat_value(stat_id),
		})

	return rows


func _character_detail_description(key_stats: Array) -> String:
	var lines := PackedStringArray()
	lines.append("Level %d" % maxi(player_level, 1))
	lines.append("Progress: %d/%d" % [clampi(level_progress_current, 0, maxi(level_progress_required, 1)), maxi(level_progress_required, 1)])
	lines.append("")
	lines.append("Core Stats")
	for row in key_stats:
		var row_data := row as Dictionary
		lines.append("%s: %s" % [String(row_data.get("name", "Stat")), String(row_data.get("value", "0"))])
	_append_forged_trait_summary(lines)
	return "\n".join(lines)


func _append_forged_trait_summary(lines: PackedStringArray) -> void:
	var loadout := _forged_trait_loadout()
	if loadout == null:
		return

	lines.append("")
	lines.append("Forged Traits")
	if loadout.has_method("get_unspent_trait_points"):
		lines.append("Ability Points: %d" % int(loadout.call("get_unspent_trait_points")))
	if loadout.has_method("get_active_traits") and loadout.has_method("get_active_slot_limit"):
		var active_traits: Array = loadout.call("get_active_traits")
		lines.append("Active Slots: %d/%d" % [active_traits.size(), int(loadout.call("get_active_slot_limit"))])
		if active_traits.is_empty():
			lines.append("Active: None")
		else:
			for raw_trait_id in active_traits:
				var trait_id := StringName(String(raw_trait_id))
				var rank := int(loadout.call("get_trait_rank", trait_id)) if loadout.has_method("get_trait_rank") else 1
				lines.append("%s Rank %d" % [ForgedTraitCatalog.get_display_name(trait_id), rank])


func _forged_trait_loadout() -> Node:
	if _stats == null:
		return null

	return _stats.get_node_or_null("ForgedTraits")


func _stat_display_name(stat_id: StringName) -> String:
	if _stats != null and _stats.has_method("get_display_name"):
		return String(_stats.call("get_display_name", stat_id))

	return _format_slot_label(String(stat_id))


func _format_stat_value(stat_id: StringName) -> String:
	if _stats == null or not _stats.has_method("get_stat"):
		return "0"

	var value := float(_stats.call("get_stat", stat_id))
	var format := &"number"
	if _stats.has_method("get_format"):
		format = StringName(String(_stats.call("get_format", stat_id)))

	match format:
		&"percent":
			return "%s%%" % _format_decimal(value)
		&"per_second":
			return "%s/s" % _format_decimal(value)
		&"kilogram":
			return "%s kg" % _format_decimal(value)
		&"per_day":
			return "%s/d" % _format_decimal(value)
		_:
			return _format_decimal(value)


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


func _on_detail_list_item_pressed(item_id: String) -> void:
	match _active_detail_id:
		"creatures":
			if not CREATURE_DETAIL_ENTRIES.has(item_id):
				return
			_remember_detail_list_scroll(_active_detail_id)
			_selected_creature_id = item_id
			_update_detail_view()
			call_deferred("_restore_detail_list_scroll", _active_detail_id)
		"crafting":
			var recipes := CraftingRecipeCatalogScript.create_recipe_lookup()
			if not recipes.has(item_id):
				return
			_remember_detail_list_scroll(_active_detail_id)
			_selected_crafting_recipe_id = item_id
			_update_detail_view()
			call_deferred("_restore_detail_list_scroll", _active_detail_id)


func _remember_detail_list_scroll(detail_id: String) -> void:
	var scroll := _current_detail_list_scroll()
	if scroll == null:
		return

	_detail_list_scroll_offsets[detail_id] = scroll.scroll_vertical


func _restore_detail_list_scroll(detail_id: String) -> void:
	var scroll := _current_detail_list_scroll()
	if scroll == null:
		return

	scroll.scroll_vertical = int(_detail_list_scroll_offsets.get(detail_id, 0))


func _current_detail_list_scroll() -> ScrollContainer:
	if _detail_body == null:
		return null

	return _detail_body.find_child("EntryScroll", true, false) as ScrollContainer


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


func _detail_item_data(item: Variant) -> Dictionary:
	if item is Dictionary:
		var item_data := item as Dictionary
		var item_label := String(item_data.get("label", item_data.get("id", "Entry")))
		return {
			"id": String(item_data.get("id", item_label)),
			"label": item_label,
		}

	var item_label := String(item)
	return {
		"id": item_label,
		"label": item_label,
	}


func _creature_detail_content() -> Dictionary:
	if not CREATURE_DETAIL_ENTRIES.has(_selected_creature_id):
		_selected_creature_id = String(CREATURE_ENTRY_ORDER[0])

	var selected_entry := CREATURE_DETAIL_ENTRIES[_selected_creature_id] as Dictionary
	var selected_label := String(selected_entry.get("label", "Creature"))
	var items: Array = []
	for creature_id in CREATURE_ENTRY_ORDER:
		if not CREATURE_DETAIL_ENTRIES.has(creature_id):
			continue

		var entry := CREATURE_DETAIL_ENTRIES[creature_id] as Dictionary
		items.append({
			"id": String(creature_id),
			"label": String(entry.get("label", creature_id)),
		})

	return {
		"title": "Creatures",
		"left_title": "Known Creatures",
		"items": items,
		"selected": selected_label,
		"creature_id": _selected_creature_id,
		"vulnerabilities": selected_entry.get("vulnerabilities", []),
		"right_title": String(selected_entry.get("right_title", selected_label)),
		"description": String(selected_entry.get("description", "Creature details will appear here.")),
	}


func _crafting_detail_content() -> Dictionary:
	var recipes := CraftingRecipeCatalogScript.create_recipes()
	var recipe_lookup := {}
	var items: Array = []
	for recipe in recipes:
		var recipe_data := recipe as Dictionary
		var recipe_id := String(recipe_data.get("id", ""))
		if recipe_id.is_empty():
			continue

		recipe_lookup[recipe_id] = recipe_data
		items.append({
			"id": recipe_id,
			"label": "%s - %s" % [
				String(recipe_data.get("category", "Crafting")),
				String(recipe_data.get("label", recipe_id)),
			],
		})

	if items.is_empty():
		return {
			"title": "Crafting",
			"left_title": "Craftable Items",
			"items": [],
			"selected": "",
			"right_title": "Crafting",
			"description": "No craftable prototype items are registered yet.",
		}

	if not recipe_lookup.has(_selected_crafting_recipe_id):
		var first_item := items[0] as Dictionary
		_selected_crafting_recipe_id = String(first_item.get("id", ""))

	var selected_recipe := recipe_lookup[_selected_crafting_recipe_id] as Dictionary
	var selected_label := String(selected_recipe.get("label", "Recipe"))
	return {
		"title": "Crafting",
		"left_title": "Craftable Items",
		"items": items,
		"selected": "%s - %s" % [
			String(selected_recipe.get("category", "Crafting")),
			selected_label,
		],
		"center_title": "Ingredients",
		"center_hint": String(selected_recipe.get("station_name", "Crafting Station")),
		"output_text": "x%d %s" % [
			maxi(int(selected_recipe.get("output_quantity", 1)), 1),
			selected_label,
		],
		"ingredients": selected_recipe.get("ingredients", []),
		"right_title": selected_label,
		"description": _crafting_detail_description(selected_recipe),
	}


func _crafting_detail_description(recipe: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append(String(recipe.get("lore", "Crafting lore will appear here.")).strip_edges())
	lines.append("")
	lines.append("Station: %s" % String(recipe.get("station_name", "Crafting Station")))
	lines.append("Tier: %s" % String(recipe.get("tier_roman", recipe.get("tier", ""))))
	lines.append("")
	lines.append(String(recipe.get("description", "")).strip_edges())
	return "\n".join(lines)


func _detail_content(detail_id: String) -> Dictionary:
	if detail_id == "creatures":
		return _creature_detail_content()
	if detail_id == "crafting":
		return _crafting_detail_content()
	if detail_id == "inventory":
		return _inventory_detail_content()
	if detail_id == "character":
		return _character_detail_content()

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
