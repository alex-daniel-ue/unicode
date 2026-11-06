@tool
extends Node
## Editor help for a block scene: points every component's `base` at the block
## that holds them, with a button and whenever the scene opens.

@warning_ignore("unused_private_class_variable")
@export_tool_button("Update component bases") var _update_bases_button := update_bases


func _ready() -> void:
	if Engine.is_editor_hint():
		update_bases()


func update_bases() -> void:
	var base := get_parent() as Block
	for child in base.get_children():
		if child is BlockBaseComponent:
			child.base = base
