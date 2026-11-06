@tool
extends Node
## Shared helpers: the main scenes, the block a node belongs to, and Python's
## view of values (its keywords, how it spells a value, its type names).

const MAIN_MENU := "res://menus/main/main_menu.tscn"
const LEVEL_SELECT := "res://menus/level select/level_select.tscn"
const PUZZLE := "res://puzzle/puzzle.tscn"
const PYTHON_KEYWORDS: Array[String] = [
	"False", "None", "True", "and", "as", "assert", "async", "await", "break",
	"class", "continue", "def", "del", "elif", "else", "except", "finally", "for",
	"from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
	"or", "pass", "raise", "return", "try", "while", "with", "yield",
]


## A config file that sits beside the game, where it can be edited without a
## rebuild: beside project.godot in the editor, beside the executable in an export.
func config_path(file_name: String) -> String:
	var folder := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir()
	return folder.path_join(file_name)


## The block `of_node` is part of: itself, or the nearest Block above it.
func get_block(of_node: Node) -> Block:
	if of_node == null:
		return null
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	while of_node != null:
		if of_node is Block:
			return of_node
		of_node = of_node.get_parent()
	return null


## Empty when `value` is one of `types`, otherwise the message a block shows:
## "2nd argument must be an integer or a decimal."
func validate_type(value: Variant, types: PackedInt32Array, idx := -1) -> String:
	const TYPE_MAPPING := {
		TYPE_BOOL: "a Boolean",
		TYPE_INT: "an integer",
		TYPE_FLOAT: "a decimal",
		TYPE_STRING: "a string",
		TYPE_STRING_NAME: "a variable name",
		TYPE_ARRAY: "a list",
	}

	if typeof(value) not in types:
		var required_types: PackedStringArray
		for type in types:
			required_types.append(TYPE_MAPPING[type])
		var message := "Value must be "
		if idx > -1:
			message = "%s argument must be " % _to_ordinal(idx + 1)
		return message + _join_choices(required_types) + "."

	if types.size() == 1 and types[0] == TYPE_STRING_NAME and String(value) in PYTHON_KEYWORDS:
		return "'%s' is a Python keyword, so it can't be a variable name." % value
	return ""


## How a value is spelled for a student. The game teaches Python, so everything
## that shows a value agrees with it: booleans are True and False, an unset
## variable is None, where GDScript's str() gives "true" and "<null>".
##
## Two forms, as in Python. This print form shows text bare; the repr form
## (to_python_repr) quotes it, which is how it appears inside a list.
func to_python_literal(value: Variant) -> String:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(value)
	return to_python_repr(value)


func to_python_repr(value: Variant) -> String:
	if value is ListEntity:
		return (value as ListEntity).repr()
	if value is DictEntity:
		return (value as DictEntity).repr()
	if value is FileEntity:
		return (value as FileEntity).repr()
	match typeof(value):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if value else "False"
		TYPE_STRING, TYPE_STRING_NAME:
			return "'%s'" % String(value).c_escape()
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for item: Variant in (value as Array):
				parts.append(to_python_repr(item))
			return "[" + ", ".join(parts) + "]"
	return str(value)


## Python's name for the type of `variant`: "list", "dict", "file", a class name
## for other objects, or Godot's own name for a built-in type.
func get_type_string(variant: Variant) -> String:
	if variant == null:
		return "null"
	if variant is ListEntity:
		return "list"
	if variant is DictEntity:
		return "dict"
	if variant is FileEntity:
		return "file"
	if variant is Object:
		var script: Variant = (variant as Object).get_script()
		if script and script.get_global_name() != &"":
			return str(script.get_global_name())
		return (variant as Object).get_class()
	return type_string(typeof(variant))


## "a, b or c".
func _join_choices(choices: Array, conjunction := "or") -> String:
	choices = choices.map(str)
	match len(choices):
		0: return ""
		1: return choices[0]
	var last := len(choices) - 1
	return ", ".join(choices.slice(0, last)) + (" %s %s" % [conjunction, choices[last]])


func _to_ordinal(n: int) -> String:
	var suffix := ""
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	else:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
			_: suffix = "th"
	return str(n) + suffix
