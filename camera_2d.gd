extends Camera2D

var zoom_speed := 0.05
var min_zoom := 0.5
var max_zoom := 3.0

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var zoom_direction := 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom_direction = -1
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_direction = 1
		_:
			return
	
	zoom *= 1 + zoom_direction * zoom_speed
	zoom = zoom.clampf(min_zoom, max_zoom)
