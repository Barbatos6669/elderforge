## Shared three-by-three layout contract for the persistent gameplay HUD.
##
## Every always-on HUD root occupies one cell. The roots clip their children,
## which keeps a large chat panel, action bar, or minimap from spilling into a
## neighboring system when the window is resized.
class_name HudGridLayout
extends RefCounted

enum Zone {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MIDDLE_LEFT,
	MIDDLE_CENTER,
	MIDDLE_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
}

const COLUMN_COUNT := 3
const ROW_COUNT := 3
const DEFAULT_OUTER_MARGIN := Vector2(16.0, 16.0)
const DEFAULT_GUTTER := Vector2(8.0, 8.0)
const ZONE_META_KEY := &"hud_grid_zone"


## Anchors a Control to one grid cell and records the assignment for tooling.
static func apply_zone(
	control: Control,
	zone: int,
	outer_margin := DEFAULT_OUTER_MARGIN,
	gutter := DEFAULT_GUTTER
) -> void:
	assert(control != null, "HudGridLayout requires a valid Control.")
	assert(zone >= Zone.TOP_LEFT and zone <= Zone.BOTTOM_RIGHT, "Invalid HUD grid zone.")

	var column := zone % COLUMN_COUNT
	var row := floori(float(zone) / float(COLUMN_COUNT))
	control.anchor_left = float(column) / float(COLUMN_COUNT)
	control.anchor_top = float(row) / float(ROW_COUNT)
	control.anchor_right = float(column + 1) / float(COLUMN_COUNT)
	control.anchor_bottom = float(row + 1) / float(ROW_COUNT)
	control.offset_left = outer_margin.x if column == 0 else gutter.x
	control.offset_top = outer_margin.y if row == 0 else gutter.y
	control.offset_right = -outer_margin.x if column == COLUMN_COUNT - 1 else -gutter.x
	control.offset_bottom = -outer_margin.y if row == ROW_COUNT - 1 else -gutter.y
	control.clip_contents = true
	control.set_meta(ZONE_META_KEY, zone)


## Returns the pixel-space cell used by tests and future layout tooling.
static func rect_for_viewport(
	viewport_size: Vector2,
	zone: int,
	outer_margin := DEFAULT_OUTER_MARGIN,
	gutter := DEFAULT_GUTTER
) -> Rect2:
	var column := zone % COLUMN_COUNT
	var row := floori(float(zone) / float(COLUMN_COUNT))
	var cell_size := Vector2(
		viewport_size.x / float(COLUMN_COUNT),
		viewport_size.y / float(ROW_COUNT)
	)
	var leading := Vector2(
		outer_margin.x if column == 0 else gutter.x,
		outer_margin.y if row == 0 else gutter.y
	)
	var trailing := Vector2(
		outer_margin.x if column == COLUMN_COUNT - 1 else gutter.x,
		outer_margin.y if row == ROW_COUNT - 1 else gutter.y
	)
	var position := Vector2(float(column), float(row)) * cell_size + leading
	var size := Vector2(
		maxf(cell_size.x - leading.x - trailing.x, 0.0),
		maxf(cell_size.y - leading.y - trailing.y, 0.0)
	)
	return Rect2(position, size)


static func zone_name(zone: int) -> String:
	match zone:
		Zone.TOP_LEFT:
			return "top-left"
		Zone.TOP_CENTER:
			return "top-center"
		Zone.TOP_RIGHT:
			return "top-right"
		Zone.MIDDLE_LEFT:
			return "middle-left"
		Zone.MIDDLE_CENTER:
			return "middle-center"
		Zone.MIDDLE_RIGHT:
			return "middle-right"
		Zone.BOTTOM_LEFT:
			return "bottom-left"
		Zone.BOTTOM_CENTER:
			return "bottom-center"
		Zone.BOTTOM_RIGHT:
			return "bottom-right"
		_:
			return "unknown"
