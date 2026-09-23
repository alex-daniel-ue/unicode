shader_type canvas_item;

// A full-screen dim with up to eight rounded holes cut in it.
//
// Two deliberate choices, both about exported builds rather than the editor:
//
// The holes are eight separate vec4 uniforms, not one `uniform vec4 holes[8]`.
// An array uniform has to be uploaded from a PackedVector4Array, and how that
// reaches the GPU differs between the Forward+ and the Compatibility renderer.
// An export that falls back to Compatibility (no Vulkan on a lab PC, or the
// export preset set to it) can leave the array at its zeroes: the dim draws,
// the holes never do. A plain vec4 is uploaded the same way everywhere.
//
// Positions come from UV * rect_size, in the mask's own local space, never from
// FRAGCOORD. FRAGCOORD is in window pixels, which equal the mask's local units
// only while the window is exactly the project's base size -- true in an editor
// run, false the moment an export is maximised, fullscreen or on a scaled
// display. The script computes the holes in local space too, so both agree.

uniform vec4 dim_color : source_color = vec4(0.02, 0.02, 0.08, 0.62);
uniform float dim_strength = 1.0;
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform int hole_count = 0;
uniform float feather = 6.0;
uniform float radius = 8.0;

// x, y, width, height, in the mask's local pixels.
uniform vec4 hole_0 = vec4(0.0);
uniform vec4 hole_1 = vec4(0.0);
uniform vec4 hole_2 = vec4(0.0);
uniform vec4 hole_3 = vec4(0.0);
uniform vec4 hole_4 = vec4(0.0);
uniform vec4 hole_5 = vec4(0.0);
uniform vec4 hole_6 = vec4(0.0);
uniform vec4 hole_7 = vec4(0.0);

// Signed distance to a rounded rectangle: negative inside, positive outside.
float rounded_box(vec2 p, vec4 r, float rad) {
	vec2 half_size = r.zw * 0.5;
	vec2 q = abs(p - (r.xy + half_size)) - half_size + vec2(rad);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - rad;
}

// 1 inside the hole, 0 outside, with a soft edge `feather` pixels wide.
float opening(vec2 p, vec4 r) {
	if (r.z <= 0.0 || r.w <= 0.0) {
		return 0.0;
	}
	float rad = min(radius, min(r.z, r.w) * 0.5);
	return 1.0 - smoothstep(0.0, max(feather, 0.001), rounded_box(p, r, rad));
}

void fragment() {
	vec2 p = UV * rect_size;
	float open = 0.0;
	if (hole_count > 0) { open = max(open, opening(p, hole_0)); }
	if (hole_count > 1) { open = max(open, opening(p, hole_1)); }
	if (hole_count > 2) { open = max(open, opening(p, hole_2)); }
	if (hole_count > 3) { open = max(open, opening(p, hole_3)); }
	if (hole_count > 4) { open = max(open, opening(p, hole_4)); }
	if (hole_count > 5) { open = max(open, opening(p, hole_5)); }
	if (hole_count > 6) { open = max(open, opening(p, hole_6)); }
	if (hole_count > 7) { open = max(open, opening(p, hole_7)); }
	COLOR = vec4(dim_color.rgb, dim_color.a * dim_strength * (1.0 - open));
}
