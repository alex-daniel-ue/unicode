class_name Core
extends Object


static func get_children_recursive(node: Node, exclude_self := false) -> Array[Node]:
	var result := _get_children(node)
	if exclude_self:
		result.pop_front()
	return result

static func _get_children(node: Node, result: Array[Node] = []) -> Array[Node]:
	result.push_back(node)
	for child: Node in node.get_children():
		result = _get_children(child, result)
	return result

static func get_block(of_node: Node) -> Block:
	if of_node == null:
		return null
	
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	
	# Iterate through self + parents and find first Block node
	while of_node != null:
		# MILD FIXME: Somewhat out of scope, checking if not SocketBlock
		# should be part of drop_manager.gd logic
		if of_node is Block:
			if of_node is SocketBlock:
				pass
			return of_node
		of_node = of_node.get_parent()
	
	# No Block parent anywhere in lineage
	return null

static func validate_type(value: Variant, types: PackedInt32Array, idx := -1) -> String:
	const TYPE_MAPPING := {
		TYPE_BOOL: "a Boolean",
		TYPE_INT: "an integer",
		TYPE_FLOAT: "a decimal",
		TYPE_STRING: "a string",
		TYPE_STRING_NAME: "a variable name",
	}
	
	if typeof(value) not in types:
		var required_types: PackedStringArray
		for type in types:
			required_types.append(TYPE_MAPPING[type])
		
		var message := "Value must be "
		if idx > -1:
			message = "%s argument must be " % _to_ordinal(idx+1)
		
		return message + _format_array(required_types) + '.'
		
	return ""

static func _format_array(arr: Array, conjunction := "or") -> String:
	arr = arr.map(str)
	match len(arr):
		0: return ""
		1: return arr[0]
	var last := len(arr)-1
	return ", ".join(arr.slice(0, last)) + (" %s %s" % [conjunction, arr[last]])

static func _to_ordinal(n: int) -> String:
	var suffix := ""
	
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	else: match n % 10:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
		_ : suffix = "th"
	
	return str(n) + suffix
