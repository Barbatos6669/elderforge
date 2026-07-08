shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform bool use_albedo_texture = true;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float dissolve_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float pixel_scale : hint_range(1.0, 64.0) = 9.0;
uniform float edge_width : hint_range(0.0, 0.25) = 0.045;
uniform vec4 edge_color : source_color = vec4(0.94, 0.88, 0.66, 0.0);
uniform float edge_glow : hint_range(0.0, 4.0) = 0.0;
uniform float material_roughness : hint_range(0.0, 1.0) = 0.92;
uniform float pattern_seed = 0.0;

varying vec3 world_position;


float block_hash(vec3 value) {
	value = fract(value * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec4 base_color = albedo_tint;
	if (use_albedo_texture) {
		base_color *= texture(albedo_texture, UV);
	}

	if (base_color.a <= alpha_scissor_threshold) {
		discard;
	}

	float visible_amount = clamp(dissolve_visibility, 0.0, 1.0);
	if (visible_amount <= 0.001) {
		discard;
	}

	if (visible_amount < 0.999) {
		vec3 cell = floor(world_position * pixel_scale + vec3(pattern_seed, pattern_seed * 1.37, pattern_seed * 2.11));
		float noise = block_hash(cell);
		float cutoff = 1.0 - visible_amount;
		if (noise < cutoff) {
			discard;
		}

		float safe_edge_width = max(edge_width, 0.0001);
		float edge_mask = 1.0 - smoothstep(cutoff, cutoff + safe_edge_width, noise);
		base_color.rgb = mix(base_color.rgb, edge_color.rgb, edge_mask * edge_color.a);
		EMISSION = edge_color.rgb * edge_mask * edge_glow;
	}

	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
	ROUGHNESS = material_roughness;
}
