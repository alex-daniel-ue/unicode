extends Control

## The main menu's picture: it covers the window, drifts a little with the
## pointer, and when the window's shape doesn't match the picture's, the part it
## crops away is chosen. `focus` is the point of the picture kept as near the
## middle of the window as covering allows: the middle of the courtyard, where
## the demo sits, so the campus around it is cropped evenly.

@export var texture: TextureRect
@export_range(0.01, 0.5, 0.01) var parallax_strength := 0.2
@export_range(1.0, 20.0, 0.5) var smooth_speed := 5.0
@export_range(1.0, 2.0, 0.01) var bg_scale_factor := 1.05
## Where in the picture (0 to 1 across and down) to keep centred.
@export var focus := Vector2(0.5, 0.5)

var initial_pos: Vector2
var viewport_size: Vector2


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_on_viewport_size_changed()

func _process(delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()

	var normalized_mouse := (mouse_position / viewport_size) * 2.0 - Vector2(1, 1)
	var max_movement_range := (texture.size - viewport_size) / 2.0
	var target_offset := normalized_mouse * max_movement_range * parallax_strength
	var target_pos := _covering(initial_pos - target_offset)

	texture.position = texture.position.lerp(target_pos, delta * smooth_speed)

func _on_viewport_size_changed() -> void:
	viewport_size = get_viewport_rect().size
	var picture := texture.texture.get_size() if texture.texture != null else viewport_size
	var cover := maxf(viewport_size.x / picture.x, viewport_size.y / picture.y) * bg_scale_factor
	texture.size = picture * cover
	texture.position = _covering(viewport_size / 2.0 - texture.size * focus)
	initial_pos = texture.position

## `at`, moved as little as needed for the picture to still cover the window.
func _covering(at: Vector2) -> Vector2:
	return Vector2(
		clampf(at.x, viewport_size.x - texture.size.x, 0.0),
		clampf(at.y, viewport_size.y - texture.size.y, 0.0))
