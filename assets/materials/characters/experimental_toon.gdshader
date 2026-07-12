shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float texture_blend : hint_range(0.0, 1.0, 0.05) = 1.0;

uniform float shade_steps : hint_range(1.0, 6.0, 1.0) = 3.0;
uniform float step_softness : hint_range(0.0, 1.0, 0.05) = 0.16;
uniform vec4 shadow_color : source_color = vec4(0.23, 0.25, 0.27, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.05) = 0.34;

uniform bool use_rim = true;
uniform vec4 rim_color : source_color = vec4(0.95, 0.84, 0.54, 1.0);
uniform float rim_power : hint_range(0.5, 8.0, 0.1) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0, 0.05) = 0.12;

uniform float roughness : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float specular : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform bool use_local_y_clip = false;
uniform float local_y_clip_min = 0.0;

varying float local_y;


float stepped_light(float value) {
	float steps = max(shade_steps, 1.0);
	float scaled = clamp(value, 0.0, 1.0) * steps;
	float step_base = floor(scaled) / steps;
	float step_next = min(step_base + (1.0 / steps), 1.0);
	float step_mix = smoothstep(0.5 - step_softness, 0.5 + step_softness, fract(scaled));
	return mix(step_base, step_next, step_mix);
}


void vertex() {
	local_y = VERTEX.y;
}


void fragment() {
	if (use_local_y_clip && local_y < local_y_clip_min) {
		discard;
	}

	vec4 base_color = albedo_color;
	if (use_albedo_texture) {
		vec4 texture_color = texture(albedo_texture, UV) * albedo_color;
		base_color = mix(albedo_color, texture_color, texture_blend);
	}

	ALBEDO = base_color.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}


void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float light_value = stepped_light(ndotl);
	vec3 tinted_shadow = mix(vec3(1.0), shadow_color.rgb, shadow_strength);
	vec3 toon_light = mix(tinted_shadow, LIGHT_COLOR, light_value);

	DIFFUSE_LIGHT += ALBEDO * toon_light;

	if (use_rim) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		rim *= smoothstep(0.0, 1.0, light_value);
		DIFFUSE_LIGHT += rim_color.rgb * rim * rim_strength;
	}
}
