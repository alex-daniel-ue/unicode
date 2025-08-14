extends MarginContainer


@export var sub_viewport: SubViewport

var level_scn := preload("res://levels/level1/level.tscn")
var current_level: Node2D


func _ready() -> void:
	current_level = level_scn.instantiate()
	sub_viewport.add_child(current_level)

func get_exposed_blocks() -> Array[Block]:
	var blocks: Array[Block]
	for child in Utils.get_children(self):
		if child is EntityData:
			blocks.append_array(child.blocks)
	return blocks
