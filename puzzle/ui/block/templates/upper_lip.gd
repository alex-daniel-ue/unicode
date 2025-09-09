@tool
extends NinePatchRect

@export var actual_minimum_size := Vector2.ZERO:
	set(value):
		actual_minimum_size = value
		if is_node_ready():
			_on_contents_resized()
@export var contents: Control

func _on_contents_resized() -> void:
	custom_minimum_size = contents.size.max(actual_minimum_size)
	
	# MEDIUM FIXME: vro🥀 what the helly
	await get_tree().process_frame
	size = Vector2.ZERO
