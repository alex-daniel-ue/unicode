class_name Util
extends Node


static func get_all_children(in_node: Node, arr: Array[Node] = []) -> Array[Node]:
	arr.push_back(in_node)
	for child: Node in in_node.get_children():
		arr = get_all_children(child, arr)
	return arr

static func log(message: Variant) -> void:
	if message is Array[Variant]:
		message = ' '.join(message)
	message = str(message)
	
	print("%.03f: %s" % [Time.get_ticks_msec() / 1000.0, message])

static func within(n: float, x: float, y: float, inclusive := false) -> bool:
	if inclusive:
		x -= 1
		y += 1
	return n > x and n < y

static func point_within(point: Vector2, vec1: Vector2, vec2: Vector2, inclusive := false) -> bool:
	var min_bound := Vector2(min(vec1.x, vec2.x), min(vec1.y, vec2.y))
	var max_bound := Vector2(max(vec1.x, vec2.x), max(vec1.y, vec2.y))
	
	return within(point.x, min_bound.x, max_bound.x, inclusive) and within(point.y, min_bound.y, max_bound.y, inclusive)
