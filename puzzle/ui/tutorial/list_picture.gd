class_name ListPicture
extends Control

## A list board as a Control, for guide pictures built in code: a real
## ListEntity, scaled by `zoom`, with this control sized around it so containers
## can place it. Set everything before it enters the tree. A "point_at" meta
## puts the board's cursor on that box, as a running program would.
## `count_boxes` lights the boxes one at a time instead, for Length Of.

## Each time a box lights while counting: how many boxes are lit so far.
signal counted(boxes: int)

## Seconds each box takes to light while counting. Fixed rather than the run
## speed's, since no program is running.
const COUNT_STEP := 0.5
## How long the whole board stays lit on the total.
const COUNT_HOLD := 1.5
const COUNT_SETTLE := 0.4
## Unlit, before counting again.
const COUNT_REST := 0.5

var list_name: StringName = &"list"
var values: Array = []
var zoom := 2.0
## Lights the boxes left to right and leaves them lit, so the lit boxes are the
## count so far; holds on the total, settles, and starts over.
var count_boxes := false

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
	if count_boxes:
		_count()


## The cards rise and glow the way a read lights them in a run.
func _count() -> void:
	var slots: Array[ListSlot] = _list._slots
	if slots.is_empty():
		return
	var tween := create_tween().set_loops()
	for i in slots.size():
		var card := slots[i].card
		var boxes := i + 1
		tween.tween_callback(func() -> void: counted.emit(boxes))
		tween.tween_property(card, "position:y", slots[i].card_rest.y - 4.0, COUNT_STEP * 0.4)
		tween.parallel().tween_property(card, "modulate", ListEntity.TINT_FLASH, COUNT_STEP * 0.4)
		tween.tween_interval(COUNT_STEP * 0.6)
	tween.tween_interval(COUNT_HOLD)
	for i in slots.size():
		if i > 0:
			tween.parallel()
		tween.tween_property(slots[i].card, "position:y", slots[i].card_rest.y, COUNT_SETTLE)
		tween.parallel().tween_property(slots[i].card, "modulate", Color.WHITE, COUNT_SETTLE)
	tween.tween_interval(COUNT_REST)
