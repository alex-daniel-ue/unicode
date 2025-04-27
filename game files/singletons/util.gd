class_name Util
extends Node


static func get_all_children(in_node: Node, arr: Array[Node] = []) -> Array[Node]:
	arr.push_back(in_node)
	for child: Node in in_node.get_children():
		arr = get_all_children(child, arr)
	return arr
