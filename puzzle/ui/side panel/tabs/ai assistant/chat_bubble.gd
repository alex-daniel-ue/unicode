class_name ChatBubble
extends HBoxContainer


@export_group("Children")
@export var panel: PanelContainer
@export var label: Label

var bubble_color := Color.WHITE:
	set(value):
		bubble_color = value
		panel.self_modulate = bubble_color

var text_color := Color.BLACK:
	set(value):
		text_color = value
		label.add_theme_color_override("font_color", text_color)

var text: String = "":
	set(value):
		text = value
		_update_bubble()

var left_aligned := true:
	set(value):
		left_aligned = value
		_update_alignment()

var max_width_ratio := 0.85


func _ready() -> void:
	_update_alignment()
	_update_bubble()

func _update_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN if left_aligned else BoxContainer.ALIGNMENT_END

func _update_bubble() -> void:
	label.text = text
	
	var max_label_width := size.x * max_width_ratio
	
	var stylebox := panel.get_theme_stylebox("panel")
	max_label_width -= stylebox.get_margin(SIDE_LEFT) + stylebox.get_margin(SIDE_RIGHT)
	
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var single_line_size := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	
	label.custom_minimum_size.x = min(single_line_size.x, max_label_width)
