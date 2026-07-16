shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(0.28, 0.76, 1.0, 1.0);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.09;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.72;
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;

void fragment() {
	float view_facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - view_facing, 2.35);
	float pulse = 0.94 + 0.06 * sin(TIME * pulse_speed);
	float alpha = (fill_alpha + rim * rim_alpha) * pulse;

	ALBEDO = shield_color.rgb;
	EMISSION = shield_color.rgb * (0.22 + rim * 0.42);
	ALPHA = clamp(alpha, 0.0, 0.82);
}
