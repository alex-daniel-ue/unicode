@tool
extends NinePatchRect


@warning_ignore("unused_private_class_variable")
@export_tool_button("Update mouth height") var _update_mouth := _on_mouth_resized
@export var mouth: Control
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var minimum_height := 0.

@onready var padding := patch_margin_top + patch_margin_bottom


func _ready() -> void:
	# Initialize mouth height
	_on_mouth_resized()


func _on_mouth_resized() -> void:
	custom_minimum_size.y = maxf(minimum_height, mouth.size.y) + padding
