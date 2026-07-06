shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D normal_map_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_map_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 deep_color : source_color = vec4(0.02, 0.14, 0.25, 1.0);
uniform vec4 mid_color : source_color = vec4(0.03, 0.34, 0.46, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.50, 0.62, 1.0);
uniform vec4 foam_color : source_color = vec4(0.72, 0.92, 0.92, 1.0);
uniform vec4 fresnel_color : source_color = vec4(0.58, 0.92, 1.0, 1.0);

uniform float water_alpha : hint_range(0.0, 1.0, 0.01) = 0.64;
uniform float depth_fade_scale : hint_range(1.0, 500.0, 1.0) = 180.0;
uniform float shallow_depth : hint_range(0.05, 8.0, 0.05) = 1.2;
uniform float deep_depth : hint_range(0.1, 16.0, 0.05) = 5.0;
uniform float normal_scale_a : hint_range(0.05, 8.0, 0.01) = 1.45;
uniform float normal_scale_b : hint_range(0.05, 12.0, 0.01) = 3.25;
uniform float texture_tile_size : hint_range(0.5, 64.0, 0.1) = 8.0;
uniform float normal_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float wave_speed : hint_range(0.0, 3.0, 0.01) = 0.22;
uniform float wave_height : hint_range(0.0, 0.35, 0.001) = 0.055;
uniform float wave_steepness : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float foam_depth : hint_range(0.01, 2.0, 0.01) = 0.34;
uniform float foam_amount : hint_range(0.0, 2.0, 0.01) = 0.32;
uniform float foam_opacity : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float fresnel_power : hint_range(0.5, 8.0, 0.1) = 3.2;
uniform float fresnel_strength : hint_range(0.0, 1.0, 0.01) = 0.38;

varying vec3 water_world_position;


float gerstner_wave(vec2 position, vec2 direction, float frequency, float speed, float amplitude, inout vec2 offset) {
	float phase = dot(position, normalize(direction)) * frequency + TIME * speed;
	float sine = sin(phase);
	float cosine = cos(phase);
	offset += normalize(direction) * cosine * amplitude * wave_steepness;
	return sine * amplitude;
}


vec3 unpack_water_normal(vec3 color) {
	return normalize(color * 2.0 - 1.0);
}


void vertex() {
	vec2 wave_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 horizontal_offset = vec2(0.0);
	float height = 0.0;
	height += gerstner_wave(wave_position, vec2(1.0, 0.28), 1.35, wave_speed * 4.2, wave_height, horizontal_offset);
	height += gerstner_wave(wave_position, vec2(-0.32, 1.0), 2.10, wave_speed * 2.7, wave_height * 0.55, horizontal_offset);
	height += gerstner_wave(wave_position, vec2(0.78, -1.0), 3.20, wave_speed * 1.8, wave_height * 0.28, horizontal_offset);

	VERTEX.xz += horizontal_offset;
	VERTEX.y += height;
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	float water_depth = max((scene_depth - FRAGCOORD.z) * depth_fade_scale, 0.0);
	float shallow_factor = 1.0 - smoothstep(0.0, shallow_depth, water_depth);
	float deep_factor = smoothstep(shallow_depth, deep_depth, water_depth);
	vec2 world_uv = water_world_position.xz / max(texture_tile_size, 0.001);

	vec2 uv_a = world_uv * normal_scale_a + vec2(TIME * wave_speed * 0.27, TIME * wave_speed * 0.13);
	vec2 uv_b = world_uv * normal_scale_b + vec2(-TIME * wave_speed * 0.19, TIME * wave_speed * 0.31);
	vec3 normal_a = unpack_water_normal(texture(normal_map_a, uv_a).rgb);
	vec3 normal_b = unpack_water_normal(texture(normal_map_b, uv_b).rgb);
	vec3 mixed_normal = normalize(vec3((normal_a.xy + normal_b.xy) * normal_strength, 1.0));
	NORMAL_MAP = mixed_normal;
	NORMAL_MAP_DEPTH = normal_strength;

	float foam_mask = 1.0 - smoothstep(0.0, foam_depth, water_depth);
	float foam_breakup = texture(foam_noise, world_uv * 4.0 + vec2(TIME * wave_speed * 0.08, -TIME * wave_speed * 0.05)).r;
	float contact_foam = foam_mask * smoothstep(0.72, 0.98, foam_breakup) * foam_amount;
	float surface_foam = smoothstep(0.94, 1.0, foam_breakup) * 0.12;
	float foam = clamp(contact_foam + surface_foam, 0.0, 1.0);

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, fresnel_power) * fresnel_strength;

	vec3 water_color = mix(shallow_color.rgb, mid_color.rgb, 1.0 - shallow_factor);
	water_color = mix(water_color, deep_color.rgb, deep_factor);
	water_color = mix(water_color, fresnel_color.rgb, fresnel);
	water_color = mix(water_color, foam_color.rgb, foam * foam_opacity);

	ALBEDO = water_color;
	ALPHA = clamp(water_alpha + foam * 0.05 + fresnel * 0.10, 0.0, 1.0);
	ROUGHNESS = mix(0.18, 0.42, foam * foam_opacity);
	SPECULAR = mix(0.85, 0.25, foam * foam_opacity);
}
