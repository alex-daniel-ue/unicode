@tool
extends MarginContainer


@export var scroll_container: ScrollContainer
@export var block_data: Array[BlockData]
@export var entities: Array[Node]


func _ready() -> void:
	get_viewport().size_changed.connect(update_vbox_height)
	update_vbox_height()
	
	if Engine.is_editor_hint():
		return
	
	block_data.map(add_to_toolbox)
	add_entity_blocks.call_deferred()

func add_to_toolbox(data_or_block: Variant) -> void:
	var block: Block
	if data_or_block is BlockData:
		data_or_block.toolbox = true
		block = Utils.construct_block(data_or_block)
	elif data_or_block is Block:
		block = data_or_block as Block
	
	$ScrollContainer/VBoxContainer.add_child(block)

func add_entity_blocks() -> void:
	for entity in entities:
		for block in entity.blocks:
			print(block)
			add_to_toolbox(block)

func update_vbox_height() -> void:
	scroll_container.custom_minimum_size.y = get_viewport_rect().size.y
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_bottom")
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_top")
