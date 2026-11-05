@tool
extends NinePatchRect


@export_tool_button("Update mouth height") var _update_mouth := _on_mouth_resized
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var minimum_height := 0.

@export_group("Children")
@export var mouth: VBoxContainer
@export var lower_lip: Control

@onready var padding := patch_margin_top + patch_margin_bottom


func _ready() -> void:
	# Initialize mouth height
	_update_mouth.call()

func _on_mouth_resized() -> void:
	custom_minimum_size.y = maxf(minimum_height, mouth.size.y) + padding
