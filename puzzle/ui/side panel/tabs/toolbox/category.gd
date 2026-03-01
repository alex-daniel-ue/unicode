extends VBoxContainer

const LABEL_HIDDEN_OPACITY := 0.7 # Increased slightly so it's more readable

@export var label: Label
@export var container: Container
@export var category_name := "Undefined":
	set = _set_category_name

func add_block(block: Block) -> void:
	container.add_child(block)

func toggle_visibility() -> void:
	container.visible = not container.visible
	label.modulate.a = 1.0 if container.visible else LABEL_HIDDEN_OPACITY
	_update_label_text()

func _set_category_name(new_name: String) -> void:
	category_name = new_name
	if is_node_ready():
		_update_label_text()

func _update_label_text() -> void:
	var prefix = "v " if container.visible else "> "
	label.text = prefix + category_name

func _ready() -> void:
	_update_label_text()

func _on_heading_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("lmb_click"):
		toggle_visibility()
