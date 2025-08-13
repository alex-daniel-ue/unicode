extends Camera2D


@onready var viewport := get_viewport()


func _ready() -> void:
	viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	offset = get_viewport_rect().size / 2
