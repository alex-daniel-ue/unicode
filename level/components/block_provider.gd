class_name BlockProvider
extends Node


@export var block_data: Array[BlockData]


## What this provider hands out. A subclass can compute it (ListBlockProvider
## builds a list's name block from the list); Level.get_block_data() reads it
## through here too, so the assistant's block doc sees the same blocks.
func get_block_data() -> Array[BlockData]:
	return block_data

func initialize_blocks() -> Array[Block]:
	var result: Array[Block]
	for data in get_block_data():
		var block := Block.construct(data)

		if data.func_type == BlockData.FuncType.ENTITY:
			block.function.object = get_parent()

		result.append(block)
	return result
