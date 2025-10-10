class_name BlockProvider
extends Node


@export var block_data: Array[BlockData]


func initialize_blocks() -> Array[Block]:
	var result: Array[Block]
	for data in block_data:
		var block := Block.construct(data)
		
		if data.func_type == BlockData.FuncType.ENTITY:
			block.function.object = get_parent()
		
		result.append(block)
	return result
