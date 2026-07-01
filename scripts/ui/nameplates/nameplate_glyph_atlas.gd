@tool
## Resource wrapper for a bitmap glyph atlas used by 3D nameplates.
##
## The atlas texture contains uppercase letters and digits. Glyph crop metadata
## lives in a JSON file generated from the source PNG so the renderer does not
## need to guess letter bounds at runtime.
class_name NameplateGlyphAtlas
extends Resource

## Transparent texture containing every supported glyph.
@export var texture: Texture2D
## JSON metadata file with glyph rectangles and advances.
@export_file("*.json") var metadata_path: String = ""
## Width used for spaces, measured as a ratio of the tallest glyph.
@export_range(0.1, 1.0, 0.01) var space_advance_ratio: float = 0.35

var _glyphs: Dictionary = {}
var _max_glyph_height := 1.0
var _metadata_loaded := false


## Returns true when the atlas has a texture and readable metadata.
func is_ready() -> bool:
	_load_metadata()
	return texture != null and not _glyphs.is_empty()


## Returns glyph data for one character, or an empty dictionary if unsupported.
func get_glyph(character: String) -> Dictionary:
	_load_metadata()
	var key := character.substr(0, 1).to_upper()
	if not _glyphs.has(key):
		return {}

	return _glyphs[key]


## Returns the tallest glyph height in pixels.
func get_max_glyph_height() -> float:
	_load_metadata()
	return _max_glyph_height


## Returns the space width in pixels.
func get_space_advance() -> float:
	return get_max_glyph_height() * space_advance_ratio


func _load_metadata() -> void:
	if _metadata_loaded:
		return

	_metadata_loaded = true
	if metadata_path.is_empty() or not FileAccess.file_exists(metadata_path):
		push_warning("Missing nameplate glyph metadata: %s" % metadata_path)
		return

	var file := FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open nameplate glyph metadata: %s" % metadata_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("glyphs"):
		push_warning("Invalid nameplate glyph metadata: %s" % metadata_path)
		return

	for key in parsed["glyphs"].keys():
		var data: Dictionary = parsed["glyphs"][key]
		var region := Rect2(
			float(data.get("x", 0.0)),
			float(data.get("y", 0.0)),
			float(data.get("width", 0.0)),
			float(data.get("height", 0.0))
		)
		var advance := float(data.get("advance", region.size.x))
		_glyphs[String(key)] = {
			"region": region,
			"advance": advance,
		}
		_max_glyph_height = maxf(_max_glyph_height, region.size.y)
