@tool
extends Node

@export_tool_button("Update component bases")
var update_bases := func() -> void:
	var base := get_parent() as Block
	for child in base.get_children():
		if child is BlockBaseComponent:
			child.base = base

func _ready() -> void:
	if Engine.is_editor_hint():
		update_bases.call()
