class_name EntityData
extends Node


@export var parent: Node
@export var block_data: Array[BlockData]

var blocks: Array[Block]


func _ready() -> void:
	for data in block_data:
		var block := Utils.construct_block(data)
		block.function = Callable(parent, data.method)
		blocks.append(block)
