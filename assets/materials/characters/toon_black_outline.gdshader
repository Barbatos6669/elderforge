shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.015, 0.012, 0.01, 1.0);
uniform float outline_width : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform bool use_local_y_clip = false;
uniform float local_y_clip_min = 0.0;
uniform float local_y_neck_min = 0.0;
uniform float local_x_neck_half_width = 0.0;

varying float local_x;
varying float local_y;


void vertex() {
	local_x = VERTEX.x;
	local_y = VERTEX.y;
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	bool inside_neck = local_y >= local_y_neck_min && abs(local_x) <= local_x_neck_half_width;
	if (use_local_y_clip && local_y < local_y_clip_min && !inside_neck) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
