class_name ListBlockProvider
extends BlockProvider
## Hands out a list's name block, from inside list_entity.tscn.
##
## Every room's board of a list answers to one name block, so only one of them
## offers it: the canonical board (lowest room_index). The block finds the
## running room's board itself when it runs.


func get_block_data() -> Array[BlockData]:
	var list := get_parent() as ListEntity
	if list == null or not list.is_canonical():
		return []
	if block_data.is_empty():
		block_data.append(ListEntity.reporter_data(list.get_list_name()))
	return block_data
