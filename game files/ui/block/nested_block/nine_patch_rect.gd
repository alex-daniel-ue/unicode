extends NinePatchRect


func _ready() -> void:
	custom_minimum_size = Vector2(
		patch_margin_left + patch_margin_right,
		patch_margin_top + patch_margin_bottom
	)
