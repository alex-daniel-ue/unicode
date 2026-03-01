@tool
extends HBoxContainer


@export var bubble_color := Color.WHITE:
	set(value):
		bubble_color = value
		if is_node_ready():
			texture.self_modulate = bubble_color

@export var text: String:
	set(value):
		text = value
		label.text = text
		dummy_label.text = text

@export var end_margin_size := 20:
	set(value):
		end_margin_size = value
		if is_node_ready():
			end_margin.custom_minimum_size.x = end_margin_size

@export var left_aligned := true:
	set = set_align

@export_group("Exports")
@export var texture: NinePatchRect
@export var label: Label
@export var dummy_label: Label
@export var end_margin: Control


func set_align(to: bool) -> void:
	left_aligned = to
	if left_aligned:
		move_child(end_margin, -1)
		#texture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		move_child(end_margin, 0)
		#texture.size_flags_horizontal = Control.SIZE_SHRINK_END
