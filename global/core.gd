@tool
extends Node


const PYTHON_KEYWORDS: Array[String] = [
	"False", "None", "True", "and", "as", "assert", "async", "await", "break",
	"class", "continue", "def", "del", "elif", "else", "except", "finally", "for",
	"from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
	"or", "pass", "raise", "return", "try", "while", "with", "yield",
]

var MAIN_MENU := load("res://menus/main/main_menu.tscn")
var LEVEL_SELECT := load("res://menus/level select/level_select.tscn")
var PUZZLE_CANVAS := load("res://puzzle/puzzle.tscn")

static var current_drag_preview: Control


func get_children_recursive(node: Node, exclude_self := false) -> Array[Node]:
	if not node.is_inside_tree():
		add_child(node)
	
	var result: Array[Node]
	_get_children(node, result)
	
	if exclude_self and result.size() > 0:
		result.pop_front()
	
	if node.get_parent() == self:
		remove_child(node)
	return result

func _get_children(node: Node, result: Array[Node] = []) -> void:
	result.push_back(node)
	for child in node.get_children():
		_get_children(child, result)

func get_block(of_node: Node) -> Block:
	if of_node == null:
		return null
	
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	
	# Iterate upward through the current node and its parents to find the first
	# Block node
	while of_node != null:
		if of_node is Block:
			return of_node
		of_node = of_node.get_parent()
	
	# Return null if no Block is found anywhere in the lineage
	return null

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
			message = "%s argument must be " % _to_ordinal(idx+1)
		
		return message + _format_array(required_types) + '.'
	
	if types.size() == 1 and types[0] == TYPE_STRING_NAME and String(value) in PYTHON_KEYWORDS:
		return "'%s' is a Python keyword, so it can't be a variable name." % value
	
	return ""

## How a value is spelled for a student.
##
## The game teaches Python, so everything that shows a value has to agree:
## booleans are True and False, an unset variable is None. GDScript's str()
## gives "true" and "<null>", which is how `print` ended up contradicting the
## watcher, the keyword check and every level text.
##
## Two forms, as in Python. The print form shows a string bare; the repr form
## quotes it, which is how it appears inside a list.
func to_python_literal(value: Variant) -> String:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(value)
	return to_python_repr(value)

func to_python_repr(value: Variant) -> String:
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

func get_type_string(variant: Variant) -> String:
	if variant == null:
		return "null"
	
	if variant is Object:
		var obj: Object = variant
		var script: Variant = obj.get_script()
		
		if script and script.get_global_name() != &"":
			return str(script.get_global_name())
		
		return obj.get_class()
	
	return type_string(typeof(variant))

func _format_array(arr: Array, conjunction := "or") -> String:
	arr = arr.map(str)
	match len(arr):
		0: return ""
		1: return arr[0]
	var last := len(arr)-1
	return ", ".join(arr.slice(0, last)) + (" %s %s" % [conjunction, arr[last]])

func _to_ordinal(n: int) -> String:
	var suffix := ""
	
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	else: match n % 10:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
		_ : suffix = "th"
	
	return str(n) + suffix
