class_name FileBlockProvider
extends BlockProvider
## Hands out a file's name block, as ListBlockProvider does a list's: only the
## canonical file of a name (the lowest room_index) offers it.

const TEMPLATE := "res://puzzle/blocks/files/file_reporter.tres"


static func reporter_data(p_name: String) -> BlockData:
	var data := (load(TEMPLATE) as BlockData).deep_copy()
	data.name = "File_%s" % p_name.replace(".", "_")
	data.text = p_name
	data.syntax = "open(\"%s\")" % p_name
	data.description = "The text file %s, shown in the room. Python opens it with open(\"%s\"). Drop it into any block that needs a file." % [p_name, p_name]
	data.func_entity_name = StringName(p_name)
	return data


func get_block_data() -> Array[BlockData]:
	var file := get_parent() as FileEntity
	if file == null or not file.is_canonical():
		return []
	if block_data.is_empty():
		block_data.append(reporter_data(file.file_name))
	return block_data
