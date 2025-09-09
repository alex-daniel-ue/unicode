extends VBoxContainer


const LABEL_HIDDEN_OPACITY := .5

@export var label: Label
@export var container: Container
@export var category_name := "Undefined":
	set = _set_category_name


func add_block(block: Block) -> void:
	container.add_child(block)

func toggle_visibility() -> void:
	container.visible = not container.visible
	label.modulate.a = 1. if container.visible else LABEL_HIDDEN_OPACITY

func _set_category_name(new_name: String) -> void:
	category_name = new_name
	label.text = new_name

func _on_heading_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("lmb_click"):
		toggle_visibility()
