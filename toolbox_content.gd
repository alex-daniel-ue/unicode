@tool
extends MarginContainer


@export_tool_button("as") var _001 := update_vbox_height
@export var scroll_container: ScrollContainer
@export var print_block: BlockData


func _ready() -> void:
	get_viewport().size_changed.connect(update_vbox_height)
	
	if Engine.is_editor_hint():
		return
	
	$ScrollContainer/VBoxContainer.add_child(Utils.construct_block(print_block))

func update_vbox_height() -> void:
	scroll_container.set_deferred("custom_minimum_size", Vector2(custom_minimum_size.x, get_viewport_rect().size.y))
