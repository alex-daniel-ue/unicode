@tool
extends MarginContainer


@warning_ignore("unused_private_class_variable")
@export_tool_button("as") var _001 := update_vbox_height
@export var scroll_container: ScrollContainer
@export var print_block: Array[BlockData]


func _ready() -> void:
	get_viewport().size_changed.connect(update_vbox_height)
	update_vbox_height()
	
	if Engine.is_editor_hint():
		return
	
	for data in print_block:
		$ScrollContainer/VBoxContainer.add_child(Utils.construct_block(data))
	
	var entity := $"../../RightSideMenu/InformationContent/Sprite2D" as Sprite2D
	await entity.ready
	for block in entity.blocks:
		$ScrollContainer/VBoxContainer.add_child(block)

func update_vbox_height() -> void:
	scroll_container.custom_minimum_size.y = get_viewport_rect().size.y
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_bottom")
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_top")
	#scroll_container.set_deferred("custom_minimum_size", Vector2(custom_minimum_size.x, get_viewport_rect().size.y))
