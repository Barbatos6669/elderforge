shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(0.23, 0.92, 0.34, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 12.0) = 3.2;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius = length(centered_uv);
	float inside_mask = 1.0 - smoothstep(0.88, 1.0, radius);
	float center_glow = pow(max(1.0 - radius, 0.0), 2.1) * 0.34;
	float outer_ring = smoothstep(0.64, 0.76, radius) * (1.0 - smoothstep(0.79, 0.91, radius));
	float inner_ring = smoothstep(0.34, 0.41, radius) * (1.0 - smoothstep(0.43, 0.51, radius));
	float angle = atan(centered_uv.y, centered_uv.x);
	float arc_breakup = 0.72 + 0.28 * sin(angle * 6.0 - TIME * 1.7);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	float alpha = (
		center_glow
		+ outer_ring * arc_breakup * 0.62
		+ inner_ring * 0.18
	) * inside_mask * pulse * intensity;

	ALBEDO = aura_color.rgb;
	EMISSION = aura_color.rgb * (0.65 + outer_ring * 0.85) * intensity;
	ALPHA = clamp(alpha, 0.0, 0.78);
}
