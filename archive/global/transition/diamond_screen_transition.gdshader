shader_type canvas_item;

// Ranges from 0 to 2 over the course of the transition.
// We use this to actually animate the shader.
uniform float progress : hint_range(0, 2);

// Size of each diamond, in pixels.
uniform float diamondPixelSize = 10.0;

void fragment() {
	float xFraction = fract(FRAGCOORD.x / diamondPixelSize);
	float yFraction = fract(FRAGCOORD.y / diamondPixelSize);
	float xDistance = abs(xFraction - 0.5);
	float yDistance = abs(yFraction - 0.5);

	if (progress <= 1.0) {
		// Phase 1: diamonds grow, covering screen from top-left to bottom-right
		if (xDistance + yDistance + UV.x + UV.y > progress * 3.0) {
			discard;
		}
	} else {
		// Phase 2: diamonds shrink, revealing screen from top-left to bottom-right
		float p2 = progress - 1.0;
		if (1.0 - xDistance - yDistance + UV.x + UV.y < p2 * 3.0) {
			discard;
		}
	}
}