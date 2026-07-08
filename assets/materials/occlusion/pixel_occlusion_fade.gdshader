shader_type spatial;
render_mode blend_mix, cull_disabled, specular_disabled;

uniform bool use_albedo_texture = true;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float occlusion_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.28;
uniform bool use_pixel_dither = false;
uniform float pixel_scale : hint_range(1.0, 64.0) = 7.0;
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

	float visible_amount = clamp(occlusion_visibility, 0.0, 1.0);
	if (visible_amount <= 0.001) {
		discard;
	}

	float output_alpha = base_color.a * visible_amount;
	if (use_pixel_dither && visible_amount < 0.999) {
		vec3 cell = floor(world_position * pixel_scale + vec3(pattern_seed, pattern_seed * 1.37, pattern_seed * 2.11));
		float noise = block_hash(cell);
		if (noise < 1.0 - visible_amount) {
			discard;
		}
		output_alpha = base_color.a;
	}

	ALBEDO = base_color.rgb;
	ALPHA = output_alpha;
	ROUGHNESS = material_roughness;
}
