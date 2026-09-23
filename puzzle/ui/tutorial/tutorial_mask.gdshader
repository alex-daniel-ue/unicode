shader_type canvas_item;

// Dims the whole screen except up to eight rounded rectangles. The holes are
// visual only; TutorialMask._has_point() is what lets clicks through them.

uniform vec4 dim_color : source_color = vec4(0.02, 0.02, 0.08, 0.62);
uniform float dim_strength = 1.0;
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform vec4 holes[8];
uniform int hole_count = 0;
uniform float feather = 6.0;
uniform float radius = 8.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float alpha = dim_color.a * dim_strength;
	for (int i = 0; i < 8; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 h = holes[i];
		float d = rounded_box(p - (h.xy + h.zw * 0.5), h.zw * 0.5, radius);
		alpha *= smoothstep(0.0, feather, d);
	}
	COLOR = vec4(dim_color.rgb, alpha);
}
