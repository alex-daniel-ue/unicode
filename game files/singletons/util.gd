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
		return n >= lower and n <= upper
	return n > lower and n < upper

static func point_within(point: Vector2, corner_a: Vector2, corner_b: Vector2, inclusive: bool) -> bool:
	var x_in_range := within(point.x, corner_a.x, corner_b.x, inclusive)
	var y_in_range := within(point.y, corner_a.y, corner_b.y, inclusive)
	
	return x_in_range and y_in_range
