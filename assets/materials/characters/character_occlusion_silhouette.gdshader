shader_type spatial;

render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled;

uniform vec4 silhouette_color : source_color = vec4(1.0, 0.72, 0.24, 0.68);
uniform float fill_strength : hint_range(0.0, 1.0, 0.01) = 0.86;


void fragment() {
	ALBEDO = silhouette_color.rgb;
	EMISSION = silhouette_color.rgb * fill_strength;
	ALPHA = silhouette_color.a;
}
