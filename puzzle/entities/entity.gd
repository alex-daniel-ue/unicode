class_name Entity
extends Sprite2D


var blocks: Array[Block]
@export var block_data: Array[BlockData]


func _ready() -> void:
	for data in block_data:
		var block := Utils.construct_block(data)
		block.function = Callable(self, data.method)
		blocks.append(block)
