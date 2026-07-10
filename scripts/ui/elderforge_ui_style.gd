## Shared UI style tokens and helpers.
##
## Keep common colors, layer numbers, and StyleBoxFlat construction here so
## HUD panels do not drift into slightly different art directions over time.
class_name ElderforgeUiStyle
extends RefCounted

const LAYER_PLAYER_STATUS := 10
const LAYER_GAME_WINDOW := 20
const LAYER_MODAL_NOTICE := 30
const LAYER_CHAT := 90
const LAYER_HUD_ACTIONS := 92
const LAYER_MASTER_MENU := 100

const COLOR_PANEL := Color(0.055, 0.062, 0.055, 0.90)
const COLOR_PANEL_DARK := Color(0.045, 0.055, 0.058, 0.88)
const COLOR_PANEL_DEEP := Color(0.02, 0.03, 0.035, 0.72)
const COLOR_PANEL_WARM := Color(0.09, 0.08, 0.065, 0.96)
const COLOR_GOLD := Color(0.86, 0.68, 0.24, 1.0)
const COLOR_GOLD_SOFT := Color(0.72, 0.58, 0.28, 0.82)
const COLOR_TEXT_PRIMARY := Color(0.96, 0.90, 0.76, 1.0)
const COLOR_TEXT_MUTED := Color(0.78, 0.82, 0.76, 1.0)
const COLOR_HEALTH := Color(0.78, 0.12, 0.08, 1.0)
const COLOR_HEALTH_EDGE := Color(0.95, 0.32, 0.18, 1.0)
const COLOR_MANA := Color(0.08, 0.36, 0.86, 1.0)
const COLOR_MANA_EDGE := Color(0.25, 0.62, 1.0, 1.0)


static func panel_style() -> StyleBoxFlat:
	return style_box(COLOR_PANEL, Color(0.56, 0.47, 0.22, 1.0), 1, 5)


static func compact_panel_style() -> StyleBoxFlat:
	return style_box(Color(0.06, 0.065, 0.055, 0.92), Color(0.55, 0.47, 0.22, 1.0), 1, 4)


static func chat_panel_style() -> StyleBoxFlat:
	return style_box(COLOR_PANEL_DEEP, Color(0.72, 0.58, 0.28, 0.42), 1, 6)


static func hud_button_style(is_hovered: bool) -> StyleBoxFlat:
	var background := Color(0.045, 0.055, 0.058, 0.98 if is_hovered else 0.88)
	return style_box(background, COLOR_GOLD_SOFT, 1, 5)


static func master_menu_button_style(is_hovered: bool) -> StyleBoxFlat:
	var background := Color(0.18, 0.13, 0.055, 1.0) if is_hovered else Color(0.10, 0.085, 0.058, 0.92)
	var border := Color(1.0, 0.86, 0.34, 1.0) if is_hovered else Color(0.72, 0.58, 0.28, 0.82)
	var style := style_box(background, border, 3 if is_hovered else 1, 6)
	if is_hovered:
		style.shadow_color = Color(0.95, 0.72, 0.22, 0.38)
		style.shadow_size = 10
	return style


static func master_menu_button_highlight_style() -> StyleBoxFlat:
	var style := style_box(Color(1.0, 0.76, 0.22, 0.18), Color(1.0, 0.92, 0.46, 0.86), 2, 5)
	style.shadow_color = Color(1.0, 0.72, 0.18, 0.30)
	style.shadow_size = 8
	return style


static func master_menu_submenu_button_style(is_hovered: bool) -> StyleBoxFlat:
	var background := Color(0.45, 0.32, 0.12, 0.96) if is_hovered else Color(0.065, 0.055, 0.045, 0.88)
	var border := Color(1.0, 0.82, 0.32, 1.0) if is_hovered else Color(0.48, 0.36, 0.18, 0.82)
	return style_box(background, border, 2 if is_hovered else 1, 3)


static func master_menu_level_bar_background_style() -> StyleBoxFlat:
	return style_box(Color(0.02, 0.019, 0.015, 0.96), Color(0.54, 0.45, 0.24, 0.82), 1, 1)


static func master_menu_level_bar_fill_style() -> StyleBoxFlat:
	return style_box(Color(0.94, 0.90, 0.80, 1.0), Color(1.0, 0.95, 0.78, 1.0), 0, 1)


static func master_menu_panel_style() -> StyleBoxFlat:
	return style_box(Color(0.055, 0.050, 0.042, 0.88), Color(0.67, 0.52, 0.22, 0.72), 1, 6)


static func master_menu_detail_panel_style() -> StyleBoxFlat:
	return style_box(Color(0.018, 0.018, 0.016, 0.64), Color(0.50, 0.37, 0.18, 0.78), 1, 2)


static func master_menu_detail_item_style(is_selected: bool) -> StyleBoxFlat:
	var background := Color(0.13, 0.11, 0.065, 0.82) if is_selected else Color(0.035, 0.032, 0.026, 0.72)
	var border := Color(0.92, 0.82, 0.58, 0.92) if is_selected else Color(0.36, 0.26, 0.13, 0.76)
	return style_box(background, border, 2 if is_selected else 1, 1)


static func tab_style(is_hovered: bool) -> StyleBoxFlat:
	var background := Color(0.05, 0.07, 0.08, 0.95 if is_hovered else 0.82)
	return style_box(background, Color(0.72, 0.58, 0.28, 0.58), 1, 5)


static func bar_background_style() -> StyleBoxFlat:
	return style_box(Color(0.025, 0.027, 0.025, 1.0), Color.BLACK, 1, 2)


static func channel_background_style() -> StyleBoxFlat:
	return style_box(Color(0.03, 0.035, 0.03, 1.0), Color(0.16, 0.18, 0.15, 1.0), 1, 2)


static func health_fill_style() -> StyleBoxFlat:
	return style_box(COLOR_HEALTH, COLOR_HEALTH_EDGE, 1, 2)


static func mana_fill_style() -> StyleBoxFlat:
	return style_box(COLOR_MANA, COLOR_MANA_EDGE, 1, 2)


static func channel_fill_style() -> StyleBoxFlat:
	return style_box(COLOR_GOLD, Color(0.96, 0.78, 0.38, 1.0), 0, 2)


static func death_panel_style() -> StyleBoxFlat:
	return style_box(Color(0.035, 0.025, 0.025, 0.88), Color(0.55, 0.08, 0.06, 1.0), 2, 5)


static func label_primary(label: Label, font_size: int, outline_size: int = 0) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline_size)


static func label_muted(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)


static func label_bar_text(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)


static func style_box(background: Color, border: Color, border_width: int = 1, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
