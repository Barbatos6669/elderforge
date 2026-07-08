shader_type spatial;

render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_front;

uniform vec4 outline_color : source_color = vec4(0.18, 1.0, 0.58, 0.92);
uniform float outline_width : hint_range(0.0, 0.18, 0.001) = 0.026;


void vertex() {
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * 0.4;
	ALPHA = outline_color.a;
}
