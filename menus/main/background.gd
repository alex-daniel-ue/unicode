extends Control


@export var texture: TextureRect
@export_range(0.01, 0.5, 0.01) var parallax_strength := 0.1
@export_range(1.0, 20.0, 0.5) var smooth_speed := 5.0
@export_range(1.0, 2.0, 0.01) var bg_scale_factor := 1.1 

var initial_pos: Vector2
var viewport_size: Vector2


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	
	var normalized_mouse := (mouse_position / viewport_size) * 2.0 - Vector2(1, 1)
	var max_movement_range := (texture.size - viewport_size) / 2.0
	var target_offset := normalized_mouse * max_movement_range * parallax_strength
	var target_pos := initial_pos - target_offset
	
	texture.position = texture.position.lerp(target_pos, delta * smooth_speed)

func _on_viewport_size_changed() -> void:
	viewport_size = get_viewport_rect().size
	
	texture.size = viewport_size * bg_scale_factor
	texture.position = (viewport_size - texture.size) / 2.0
	initial_pos = texture.position
