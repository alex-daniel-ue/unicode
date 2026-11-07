class_name DictBlockProvider
extends BlockProvider
## Hands out a dictionary's name block, as ListBlockProvider does a list's: only
## the canonical board of a name (the lowest room_index) offers it.

const TEMPLATE := "res://puzzle/blocks/dicts/dict_reporter.tres"


static func reporter_data(p_name: StringName) -> BlockData:
	var data := (load(TEMPLATE) as BlockData).deep_copy()
	data.name = "Dict_%s" % p_name
	data.text = String(p_name)
	data.syntax = String(p_name)
	data.description = "The dictionary named %s, shown on its board in the room. Drop it into any block that needs a dictionary." % p_name
	data.func_entity_name = p_name
	return data


func get_block_data() -> Array[BlockData]:
	var board := get_parent() as DictEntity
	if board == null or not board.is_canonical():
		return []
	if block_data.is_empty():
		block_data.append(reporter_data(board.get_dict_name()))
	return block_data
