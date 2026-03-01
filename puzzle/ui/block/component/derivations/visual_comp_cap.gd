extends BlockVisualComponent


@export var lower_lip: Control


func start_drag_feedback(control: Control) -> void:
	lower_lip.custom_minimum_size.y = control.size.y / 2.0

func stop_drag_feedback() -> void:
	lower_lip.custom_minimum_size.y = 0.0
