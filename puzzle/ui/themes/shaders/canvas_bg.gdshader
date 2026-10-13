shader_type canvas_item;

// The workspace's floor: a dot at every grid point, and every `major_every`
// cells a bigger dot and a faint line, like graph paper. Worked out in the
// canvas's own coordinates, so the grid is fixed to the canvas: it pans and
// zooms with the blocks, and dragging the canvas reads as moving the workspace,
// not as the program sliding about on a still screen. Kept dim enough that the
// blocks, not the grid, are what the eye goes to.

uniform float cell_size = 25.0;
uniform vec4 background_color : source_color = vec4(0.043, 0.043, 0.102, 1.0);
uniform vec4 dot_color : source_color = vec4(0.21, 0.22, 0.33, 1.0);
// Radii in canvas pixels, so the dots grow and shrink with the zoom.
uniform float dot_radius = 1.6;
uniform int major_every = 5;
uniform float major_dot_radius = 2.6;
uniform vec4 major_dot_color : source_color = vec4(0.28, 0.29, 0.43, 1.0);
uniform vec4 line_color : source_color = vec4(0.10, 0.105, 0.19, 1.0);
uniform float line_width = 1.0;
// Below this many screen pixels between dots (zoomed far out), the small dots
// fade, so the grid thins out instead of turning into noise.
uniform float min_screen_cell = 9.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Coverage of a dot of `radius` around the nearest point of a `spacing` grid,
// anti-aliased over one screen pixel (`px` canvas pixels).
float dot_mask(vec2 p, float spacing, float radius, float px) {
	vec2 nearest = round(p / spacing) * spacing;
	float d = length(p - nearest);
	return 1.0 - smoothstep(radius - px * 0.5, radius + px * 0.5, d);
}

void fragment() {
	// Canvas pixels per screen pixel: 1.0 at zoom 1, 4.0 at zoom 0.25.
	float px = max(fwidth(local_pos.x), 1e-4);
	float major = cell_size * float(max(major_every, 1));
	vec4 color = background_color;

	// Faint lines through the big dots.
	vec2 to_line = abs(local_pos - round(local_pos / major) * major);
	float half_width = max(line_width, px) * 0.5;
	float line = 1.0 - smoothstep(half_width - px * 0.5, half_width + px * 0.5, min(to_line.x, to_line.y));
	color = mix(color, line_color, line);

	// Small dots, fading out when they'd be packed too tight to read.
	float fade = smoothstep(min_screen_cell * 0.6, min_screen_cell, cell_size / px);
	color = mix(color, dot_color, dot_mask(local_pos, cell_size, max(dot_radius, px * 0.7), px) * fade);

	// Big dots.
	color = mix(color, major_dot_color, dot_mask(local_pos, major, max(major_dot_radius, px), px));

	COLOR = color;
}
