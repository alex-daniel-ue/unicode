class_name RuntimeBlocks
extends RefCounted
## Blocks that only exist once a level is running, named in a level's
## description through the template they're made from: a list's name block
## (list_reporter.tres, made per list by ListEntity) and a function's call
## block (call.tres and call_value.tres, made per function by
## FunctionDefinitions). Naming the template marks every block made from it as
## new in the Toolbox, and its guide page shows the level's first one.

const FAMILIES := {
	"res://puzzle/blocks/lists/list_reporter.tres": "List_",
	"res://puzzle/blocks/functions/call.tres": "Call_",
	"res://puzzle/blocks/functions/call_value.tres": "Call_",
	"res://puzzle/blocks/functions/call_bool.tres": "Call_",
	"res://puzzle/blocks/dicts/dict_reporter.tres": "Dict_",
	"res://puzzle/blocks/files/file_reporter.tres": "File_",
}


## The name prefix of the blocks `template` stands for, or "" when it is an
## ordinary block.
static func family_of(template: BlockData) -> String:
	if template == null:
		return ""
	return FAMILIES.get(template.resource_path, "")


## True when `data` was made from a template of `family`.
static func in_family(data: BlockData, family: String) -> bool:
	return data != null and not family.is_empty() and data.name.begins_with(family)
