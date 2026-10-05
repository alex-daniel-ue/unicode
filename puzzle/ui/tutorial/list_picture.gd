class_name ListPicture
extends Control

## A list board as a Control, for guide pictures built in code: a real
## ListEntity, scaled by `zoom`, with this control sized around it so containers
## can place it. Set everything before it enters the tree. A "point_at" meta
## puts the board's cursor on that box, as a running program would.

var list_name: StringName = &"list"
var values: Array = []
var zoom := 2.0

var _list: ListEntity


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_list = ListEntity.create()
	_list.list_name = list_name
	_list.values = values.duplicate()
	_list.scale = Vector2(zoom, zoom)
	add_child(_list)
	# Where the board reaches, from its own origin: the name sits to its left.
	var rect: Rect2 = _list._board_rect(_list.box_count())
	_list.position = -rect.position * zoom
	custom_minimum_size = rect.size * zoom
	if has_meta(&"point_at"):
		_list.point_at(int(get_meta(&"point_at")))
