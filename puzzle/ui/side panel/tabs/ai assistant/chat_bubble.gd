@tool
extends HBoxContainer


@export var bubble_color := Color.WHITE:
	set(value):
		bubble_color = value
		if is_node_ready():
			panel.self_modulate = bubble_color

@export var text_color := Color.BLACK:
	set(value):
		text_color = value
		if is_node_ready():
			label.add_theme_color_override("font_color", text_color)

@export_multiline var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			_update_bubble()

@export var left_aligned := true:
	set(value):
		left_aligned = value
		if is_node_ready():
			_update_alignment()

@export_range(0.1, 1.0) var max_width_ratio := 0.85

@export_group("Children")
@export var panel: PanelContainer
@export var label: Label


func _ready() -> void:
	_update_alignment()
	bubble_color = bubble_color
	
	resized.connect(_update_bubble)
	_update_bubble()

func _update_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN if left_aligned else BoxContainer.ALIGNMENT_END

func _update_bubble() -> void:
	if not is_node_ready() or text.is_empty() or size.x == 0:
		return
	
	label.text = text
	
	var max_bubble_width := size.x * max_width_ratio
	
	var stylebox := panel.get_theme_stylebox("panel")
	var margins := 0.0
	if stylebox:
		margins = stylebox.get_margin(SIDE_LEFT) + stylebox.get_margin(SIDE_RIGHT)
	var max_label_width := max_bubble_width - margins
	
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var single_line_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	label.custom_minimum_size.x = min(single_line_size.x + 2, max_label_width)
