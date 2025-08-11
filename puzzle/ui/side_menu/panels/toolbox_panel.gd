@tool
extends MarginContainer


@export var _internal_category_order: PackedStringArray
@export var block_data: Array[BlockData]

@export_group("Children")
@export var scroll_container: ScrollContainer
@export var vbox_container: VBoxContainer
@export var toolbox_label: Label

var category_scn := preload("res://puzzle/ui/side_menu/panels/toolbox_category.tscn")
var current_cats: Array[String]


func _ready() -> void:
	get_viewport().size_changed.connect(_expand_scroll_container)
	_expand_scroll_container()
	
	if Engine.is_editor_hint():
		return
	
	for data in block_data:
		add_block(Utils.construct_block(data))

func add_block(block: Block) -> void:
	if block.data.toolbox_category in current_cats:
		for child in vbox_container.get_children():
			if child == toolbox_label: continue
			if child.category_name == block.data.toolbox_category:
				child.add_child(block)
				return
	
	current_cats.append(block.data.toolbox_category)
	
	var new_cat := category_scn.instantiate()
	new_cat.category_name = block.data.toolbox_category
	vbox_container.add_child(new_cat)
	new_cat.add_child(block)
	
	for child in vbox_container.get_children():
		if child == toolbox_label: continue
		move_child(child, _internal_category_order.find(child.category_name))


func _expand_scroll_container() -> void:
	scroll_container.custom_minimum_size.y = get_viewport_rect().size.y
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_bottom")
	scroll_container.custom_minimum_size.y -= get_theme_constant("margin_top")
