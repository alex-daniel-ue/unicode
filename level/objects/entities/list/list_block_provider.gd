class_name ListBlockProvider
extends BlockProvider

## Hands out a list's name block. ListEntity adds one of these to itself at
## runtime; it isn't authored.
##
## A level has one shelf per room under the same name, and they all answer to one
## name block, so only one of them offers it: the canonical shelf (lowest
## room_index). The block finds the running room's shelf itself when it runs.


func get_block_data() -> Array[BlockData]:
	var list := get_parent() as ListEntity
	if list == null or not list.is_canonical():
		return []
	if block_data.is_empty():
		block_data.append(list.make_reporter_data())
	return block_data
