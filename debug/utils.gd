class_name Utils
extends Object


## Currently primarily used in changing drop preview scale for when canvas is
## zoomed out.
static var drag_preview_container: Control


## Returns itself & its children, grandchildren, and so on.
static func get_children(node: Node, result: Array[Node] = []) -> Array[Node]:
	result.push_back(node)
	for child: Node in node.get_children():
		result = get_children(child, result)
	return result

static func get_block(of_node: Node) -> Block:
	if of_node == null: return null
	
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	
	# Iterate through self + parents and find first Block node
	while of_node != null:
		# MILD FIXME: Somewhat out of scope, checking if not SocketBlock
		# should be part of drop_manager.gd logic
		if of_node is Block and not of_node is SocketBlock:
			return of_node
		of_node = of_node.get_parent()
	
	# No Block parent anywhere in lineage
	return null

static func construct_block(data: BlockData) -> Block:
	var scene := load(data.base_block_path) as PackedScene
	var block := scene.instantiate() as Block
	
	block.data = data
	block.name = block.data.block_name
	block.format_text()
	
	return block

static func typecast_string(string: String) -> Variant:
	if string.is_empty():
		return ''
	if string in ["true", "false"]:
		return str_to_var(string)
	if string.is_valid_int():
		return string.to_int()
	if string.is_valid_float():
		return string.to_float()
	
	var last := len(string)-1
	if string[last] == '"' and string[0] == '"':
		return string.substr(1, last-1)
	
	return StringName(string)

static func evaluate_arguments(this: Block) -> Result:
	var results: Array
	for block in this.get_text_blocks():
		block.parent_nested = this if this is NestedBlock else this.parent_nested
		var result: Variant = block.function.call()
		if result is Utils.Error: return result
		
		results.append(result.data)
	return Result.success(results)

static func evaluate_and_check_arguments(length: int, this: Block) -> Result:
	var result := evaluate_arguments(this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	if len(args) < length:
		return Result.error("%d argument/s are required!" % length, this)
	return Result.success(args)

static func validate_type(args: Array, idx: int, types: PackedInt32Array, this: Block) -> Result:
	const TYPE_MAPPING := {
		TYPE_BOOL: "a Boolean",
		TYPE_INT: "an integer",
		TYPE_FLOAT: "a decimal",
		TYPE_STRING: "a string",
		TYPE_STRING_NAME: "a variable name",
	}
	
	if typeof(args[idx]) not in types:
		var mapped_types := Array(types).map(func(type): return TYPE_MAPPING[type])
		Debug.log("%s %s" % [args[idx], type_string(typeof(args[idx]))])
		var err_msg := "%s argument must be %s!" % [to_ordinal(idx+1), format_array(mapped_types)]
		return Result.error(err_msg, this)
	
	return Result.success(args[idx])

static func to_ordinal(n: int) -> String:
	var suffix := ""
	
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	else: match n % 10:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
		_ : suffix = "th"
	
	return str(n) + suffix

static func format_array(arr: Array) -> String:
	arr = arr.map(str)
	match len(arr):
		0: return ""
		1: return arr[0]
	var last := len(arr)-1
	return ", ".join(arr.slice(0, last)) + (" or %s" % arr[last])




class Result:
	var data: Variant
	
	@warning_ignore("shadowed_variable")
	func _init(data: Variant) -> void:
		self.data = data
	
	static func error(msg: String, block: Block) -> Result:
		return Utils.Error.new(msg, block)
	
	@warning_ignore("shadowed_variable")
	static func success(data: Variant = null) -> Result:
		return Result.new(data)

class Error extends Result:
	var message: String
	var block: Block
	
	@warning_ignore("shadowed_variable")
	func _init(message: String, block: Block) -> void:
		self.message = message
		self.block = block

#static func get_class_ancestry(obj: Object) -> PackedStringArray:
	#var result: PackedStringArray
	#var script := obj.get_script() as Script
	#while script != null:
		#result.append(script.get_global_name())
		#script = script.get_base_script()
	#return result

#static func random_name() -> String:
	#const alphabet := "abcdefghijklmnopqrstuvwxyz"
	#
	#var result := ""
	#for i in range(randi_range(6, 15)):
		#result += alphabet[randi_range(0, len(alphabet)-1)]
	#return result
