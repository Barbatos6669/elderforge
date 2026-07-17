extends SceneTree

const EXPERIMENTAL_TOON_SHADER := preload(
	"res://assets/materials/characters/experimental_toon.gdshader"
)
const TOON_OUTLINE_SHADER := preload(
	"res://assets/materials/characters/toon_black_outline.gdshader"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for shader in [EXPERIMENTAL_TOON_SHADER, TOON_OUTLINE_SHADER]:
		var shader_code := String(shader.code)
		if (
			not shader_code.contains("local_y_neck_min")
			or not shader_code.contains("local_x_neck_half_width")
			or not shader_code.contains("inside_neck")
		):
			_fail("Outfit body masks should retain a narrow neck region in every pass.")
			return

	if (
		not is_equal_approx(
			CharacterAppearanceAssets.outfit_body_neck_min_y("starter_peasant", "male"),
			1.35
		)
		or not is_equal_approx(
			CharacterAppearanceAssets.outfit_body_neck_half_width("starter_peasant", "male"),
			0.16
		)
	):
		_fail("The starter male outfit should keep its visually validated neck mask.")
		return

	print("Character outfit mask tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
