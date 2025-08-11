@tool
extends VBoxContainer


const LABEL_HIDDEN_OPACITY := .5

@export var category_name := "Category name":
	set = _set_category_name

@export_group("Children")
@export var category_label: Label

var blocks_visible = true


func with(_category_name: String) -> VBoxContainer:
	self.category_name = _category_name
	return self

func toggle_visibility() -> void:
	blocks_visible = not blocks_visible
	category_label.modulate.a = 1. if blocks_visible else LABEL_HIDDEN_OPACITY
	
	for child in get_children():
		if child != category_label:
			child.visible = blocks_visible

func _set_category_name(new_name: String) -> void:
	category_name = new_name
	category_label.text = category_name

func _on_label_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		event.pressed):
			toggle_visibility()
