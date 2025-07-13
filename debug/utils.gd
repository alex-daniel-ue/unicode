class_name Utils
extends Object


static func get_children(node: Node, result: Array[Node] = []) -> Array[Node]:
	result.push_back(node)
	for child: Node in node.get_children():
		result = get_children(child, result)
	return result


static func log(message: Variant = "") -> void:
	if message is Array[Variant]:
		message = ' '.join(message)
	message = str(message) 
	
	print_rich("%.03f:\t%s" % [Time.get_ticks_msec() / 1000.0, message])


static func get_block(of_node: Node) -> Block:
	if of_node == null:
		return null
	
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	
	# Iterate through self + parents and find first Block node
	while of_node != null:
		if of_node is Block:
			return of_node
		of_node = of_node.get_parent()
	
	# No Block parent anywhere
	return null


static func random_name() -> String:
	const alphabet := "abcdefghijklmnopqrstuvwxyz"
	
	var result := ""
	for i in range(randi_range(6, 15)):
		result += alphabet[randi_range(0, len(alphabet)-1)]
	return result
