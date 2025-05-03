class_name Util
extends Node


static func get_all_children(in_node: Node, arr: Array[Node] = []) -> Array[Node]:
	arr.push_back(in_node)
	for child: Node in in_node.get_children():
		arr = get_all_children(child, arr)
	return arr

static func log(message: Variant = "") -> void:
	if message is Array[Variant]:
		message = ' '.join(message)
	message = str(message)
	
	print_rich("%.03f: %s" % [Time.get_ticks_msec() / 1000.0, message])

static func within(n: float, x: float, y: float, inclusive := false) -> bool:
	var lower := minf(x, y)
	var upper := maxf(x, y)
	if inclusive:
		lower -= 1
		upper += 1
	
	return n > lower and n < upper

static func point_within(point: Vector2, vec1: Vector2, vec2: Vector2, inclusive := false) -> bool:
	return within(point.x, vec1.x, vec2.x, inclusive) and within(point.y, vec1.y, vec2.y, inclusive)
