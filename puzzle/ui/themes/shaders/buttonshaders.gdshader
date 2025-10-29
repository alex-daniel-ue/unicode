shader_type canvas_item;

uniform bool hover = false;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    if (hover) {
        // Add simple glow by increasing brightness
        COLOR = base_color + vec4(0.5, 0.5, 0.5, 0.0);
    } else {
        COLOR = base_color;
    }
}