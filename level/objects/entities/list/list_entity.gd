@tool
class_name ListEntity
extends Node2D

## A list that lives in a room, drawn the way a list is drawn on a classroom
## whiteboard: its name, a row of boxes holding its values in order, and each
## box's index underneath, starting at 0. The level makes it; the student reads
## and changes it through blocks, and the board shows every change.
##
## One board per room. A level puts a board in every room that needs the list,
## all with the same list_name and each with its own room_index, and the name
## block a student drags finds the board of the room that's running (find()).
## So every room's contents are on screen before Play, the way every room's walls
## are, and nothing has to move between rooms.
##
## The operations are called by list_functions.gd with the calling block last,
## the way robot.gd's are, and pace themselves with Interpreter.step(). The
## errors are raised here, in Python's terms, because only the list knows its
## own name and length.
##
## Author it by instancing list_entity.tscn under Visuals, usually on a room's
## wall, and filling in `values`. Its origin is the top-left corner of box 0; the
## name sits to the left of the boxes. The scene holds the board's parts; this
## script lays them out for the number of boxes and instances one list_slot.tscn
## per box.

const GROUP := &"list_entity"
const SCENE_PATH := "res://level/objects/entities/list/list_entity.tscn"
const SLOT_SCENE := preload("res://level/objects/entities/list/list_slot.tscn")
const REPORTER_TEMPLATE := "res://puzzle/blocks/lists/list_reporter.tres"

## One box per tile.
const CELL := 32.0
## The index row under the boxes.
const INDEX_ROW := 18.0
## The board's margin around its contents, and the gap between name and boxes.
const PAD := 6.0
const PAD_TOP := 5.0
const NAME_GAP := 8.0
## Longest a list may grow. Python lists have no limit, but a loop that appends
## to the list it's going through never ends, so the board stops it here.
const MAX_ITEMS := 20
## Longest a value takes to fly from one board to another.
const FLIGHT_TIME := 0.45
## Longest an animation runs; slower speeds still leave a still frame to read.
const ANIM_TIME := 0.25
## The ghost box for an out-of-range index is drawn at most this far past the end.
const GHOST_REACH := 3
## How many recent reads a written value can fly from (see _sources).
const SOURCES_KEPT := 4
## How far a standing board's legs reach below it.
const LEG_LENGTH := 8.0

## Tints over the cards and boxes.
const TINT_EMPTY := Color(0.86, 0.88, 0.92)
const TINT_FLASH := Color("#ffd166")
## A value the program wrote that matches the goal, or doesn't.
const TINT_RIGHT := Color("#b6ecc6")
const TINT_WRONG := Color("#ffb8b8")

## What students read, and what the name block says. Empty means the node's name.
@export var list_name: StringName = &"":
	set(value):
		list_name = value
		_rebuild()
		update_configuration_warnings()
## Which room this board belongs to, counted from 0 like Resettable's rooms, so
## Room 1 is 0. Ignored when the level has only one board with this name.
@export var room_index := 0
@export var values: Array = []:
	set(value):
		values = value
		_rebuild()
## On legs, like a whiteboard on wheels, for a board that stands on the floor
## rather than hanging on the wall.
@export var standing := false:
	set(value):
		standing = value
		_rebuild()

## The last few boxes values were read from, anywhere in the level, newest last:
## where a value flies from when it's written into a list. A few rather than one,
## because a program often reads something else in between, as in
## `if b != item -1 of tidy: append b to tidy`. Cleared at each run.
static var _sources: Array[Dictionary] = []

var _initial: Array = []
var _slots: Array[ListSlot] = []
## What a ListGoal wants this list to end up as, shown on the board so the goal
## is on screen the way a flag is. Empty and unused without a goal.
var _target: Array = []
var _has_target := false
## Positions the program has written this run. Only written values are marked
## right or wrong, so a list that starts off different from its goal (AR-7's
## lockers) isn't red before anything runs.
var _written: Array = []

@onready var _board: Panel = get_node_or_null(^"Board")
@onready var _legs: Node2D = get_node_or_null(^"Legs")
@onready var _name: Label = get_node_or_null(^"Name")
@onready var _caption: Label = get_node_or_null(^"IndexCaption")
@onready var _slot_holder: Node2D = get_node_or_null(^"Slots")
@onready var _cursor: Panel = get_node_or_null(^"Cursor")
@onready var _ghost: Panel = get_node_or_null(^"Ghost")
@onready var _ghost_index: Label = get_node_or_null(^"GhostIndex")


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_initial = values.duplicate(true)
	# Only a level's boards are lists a program can reach; a guide's picture of
	# one is just a picture, and a run mustn't restore it.
	if Game.level != null and Game.level.is_ancestor_of(self):
		add_to_group(GROUP)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PATH_RENAMED and list_name.is_empty():
		_rebuild()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_node_or_null(^"Slots") == null:
		warnings.append("This is the ListEntity script on its own. Instance list_entity.tscn instead; the board's parts live in the scene.")
	var shown := String(get_list_name())
	if not shown.is_valid_ascii_identifier():
		warnings.append("'%s' isn't a name Python would accept, and students will read it as one." % shown)
	return warnings


#region Queries
func get_list_name() -> StringName:
	return list_name if not list_name.is_empty() else StringName(name)

## Python's name for what this is. Only lists now; the watcher and the
## assistant still ask.
func kind_name() -> String:
	return "list"

## The values as Python writes them: [1, 2].
func repr() -> String:
	return repr_of(values)

## What the level started this list with, as Python writes it.
func initial_repr() -> String:
	return repr_of(_initial)

func repr_of(items: Array) -> String:
	var parts := PackedStringArray()
	for item: Variant in items:
		parts.append(Core.to_python_repr(item))
	return "[" + ", ".join(parts) + "]"

## True when the contents equal `expected` in Python's terms: 3 and "3" differ,
## 3 and 3.0 don't.
func matches(expected: Array) -> bool:
	if expected.size() != values.size():
		return false
	for i in expected.size():
		if not same(values[i], expected[i]):
			return false
	return true

## Boxes drawn: one per value, and one per value the goal still wants.
func box_count() -> int:
	return maxi(values.size(), _target.size())

## Called by a ListGoal: what this list should end up holding.
func set_target(expected: Array) -> void:
	_has_target = true
	_target = expected.duplicate()
	_rebuild()

## For guide pictures: shows `shown` with `target` as its goal, as if the program
## had written the positions in `written`.
func show_example(shown: Array, target: Array, written: Array = []) -> void:
	_target = target.duplicate()
	_has_target = not target.is_empty()
	values = shown.duplicate()
	_written = written.duplicate()
	_refresh_marks()

## The whole board in global coordinates. Worked out from the exported values
## rather than measured from the nodes, so it is right before _ready() has laid
## the board out, which is when the editor's LevelCamera measures a level.
## LevelCamera.node_bounds() asks for it.
func get_global_bounds() -> Rect2:
	var rect := _board_rect(box_count())
	if standing:
		rect.size.y += LEG_LENGTH
	return global_transform * rect

## Among every board of this name in the level, the one that hands out the name
## block: the lowest room_index, then the first in the tree.
func is_canonical() -> bool:
	var best: ListEntity = null
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as ListEntity
		if other == null or other.get_list_name() != get_list_name():
			continue
		if best == null or other.room_index < best.room_index:
			best = other
	return best == self

## A new board from the scene, for code that needs one (the level checks).
static func create() -> ListEntity:
	return (load(SCENE_PATH) as PackedScene).instantiate() as ListEntity

## The board a block means by `p_name` right now: the only one with that name, or
## the one in the room that's running.
static func find(p_name: StringName) -> ListEntity:
	var level := Game.level
	if level == null or not level.is_inside_tree():
		return null
	var named: Array[ListEntity] = []
	for node in level.get_tree().get_nodes_in_group(GROUP):
		var list := node as ListEntity
		if list != null and list.get_list_name() == p_name and level.is_ancestor_of(list):
			named.append(list)
	if named.size() == 1:
		return named[0]
	for list in named:
		if list.room_index == level.current_room:
			return list
	return null

## Why find() came back empty, for the block that asked.
static func missing_message(p_name: StringName) -> String:
	var level := Game.level
	if level != null and level.room_goals.size() > 1:
		return "There's no list named '%s' in Room %d." % [p_name, level.current_room + 1]
	return "There's no list named '%s' here." % p_name

## The name block for a list: a round block that is just the list's name, like
## Scratch's variable reporters. Built from a template so its look is editable.
static func reporter_data(p_name: StringName) -> BlockData:
	var data := (load(REPORTER_TEMPLATE) as BlockData).deep_copy()
	# Unique per list: the assistant's block doc is keyed by name.
	data.name = "List_%s" % p_name
	data.text = String(p_name)
	data.syntax = String(p_name)
	data.description = (
		"The list named %s, shown on its board in the room. Drop it into any block that needs a list."
		% p_name
	)
	data.func_entity_name = p_name
	return data

func make_reporter_data() -> BlockData:
	return reporter_data(get_list_name())

## Equality in Python's terms: numbers compare by value, anything else only
## against the same kind of thing.
static func same(a: Variant, b: Variant) -> bool:
	var number_a := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var number_b := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if number_a and number_b:
		return a == b
	if typeof(a) != typeof(b):
		return false
	return a == b
#endregion


#region Operations (called by list_functions.gd; each paces itself)
## item {index} of {list}
func read(index: Variant, from_this: Block) -> Variant:
	var i: Variant = _checked_index(index, from_this, "item")
	if i == null:
		return null
	_flash(i, index)
	_remember(i)
	await Interpreter.step(from_this)
	var value: Variant = values[i]
	return value.duplicate(true) if value is Array else value

## set item {index} of {list} to {value}
func write(index: Variant, value: Variant, from_this: Block) -> void:
	if not _storable(value, from_this):
		return
	var i: Variant = _checked_index(index, from_this, "set item")
	if i == null:
		return
	values[i] = value
	_slots[i].value_label.text = _value_text(value)
	_written.append(i)
	_arrive(_slots[i], value, true)
	_refresh_marks()
	await Interpreter.step(from_this)

## length of {list}
func size(from_this: Block) -> int:
	flash_name()
	for i in values.size():
		_flash_card(_slots[i])
	await Interpreter.step(from_this)
	return values.size()

## append {value} to {list}
func append_value(value: Variant, from_this: Block) -> void:
	if not _storable(value, from_this):
		return
	if values.size() >= MAX_ITEMS:
		from_this.function.error(
			"'%s' already has %d items. Is something being added to the list a loop is going through?"
			% [get_list_name(), values.size()]
		)
		return
	values.append(value)
	var i := values.size() - 1
	_ensure_slots(values.size())
	_fill_slot(i)
	_written.append(i)
	_arrive(_slots[i], value)
	_refresh_marks()
	await Interpreter.step(from_this)

## {value} in {list}: looks at each item in turn, as Python does.
func contains(value: Variant, from_this: Block) -> bool:
	var found := -1
	for i in values.size():
		if same(values[i], value):
			found = i
			break
	var last := found if found >= 0 else values.size() - 1
	for i in last + 1:
		_flash_card(_slots[i], float(i) / maxf(1.0, last + 1.0))
	await Interpreter.step(from_this)
	return found >= 0

## Outlines box `i` as the one a for each is on; a negative index clears it.
func point_at(i: int) -> void:
	if _cursor == null:
		return
	_cursor.visible = i >= 0 and i < _slots.size()
	if _cursor.visible:
		_cursor.position = Vector2(i * CELL, 0)
		if i < values.size():
			_remember(i)

func flash_name() -> void:
	if _name == null or Engine.is_editor_hint():
		return
	var tween := create_tween()
	tween.tween_property(_name, "modulate", TINT_FLASH, _anim_time() * 0.4)
	tween.tween_property(_name, "modulate", Color.WHITE, _anim_time() * 0.6)

## Back to the contents the level was authored with. Redraws, which also clears
## the cursor and any ghost box left by the last run.
func restore() -> void:
	_written.clear()
	_sources.clear()
	values = _initial.duplicate(true)
#endregion


#region Checks shared by the operations
## The index as a position in `values`, or null after raising the error.
func _checked_index(index: Variant, from_this: Block, what: String) -> Variant:
	var list_label := get_list_name()
	if typeof(index) == TYPE_FLOAT:
		from_this.function.error("An index has to be a whole number, but it's %s. Use // to divide without a decimal." % index)
		return null
	if typeof(index) != TYPE_INT:
		from_this.function.error("An index has to be a whole number, but it's %s." % Core.to_python_repr(index))
		return null

	var count := values.size()
	var i: int = index
	if i < -count or i >= count:
		_show_ghost(i)
		# set item on an empty list is an attempt to add an item. Past the end of
		# a list that has items it's usually an off-by-one, where pointing at
		# append would send the student the wrong way.
		var hint := " set item only changes items that are already there; append adds a new one." \
				if what == "set item" and count == 0 else ""
		if count == 0:
			from_this.function.error("'%s' is empty, so it has no item %d.%s" % [list_label, i, hint])
		else:
			from_this.function.error(
				"Index %d is out of range. '%s' has %d item%s, at indexes 0 to %d.%s"
				% [i, list_label, count, "" if count == 1 else "s", count - 1, hint]
			)
		return null
	# Python counts negative indices from the end: -1 is the last item.
	return i + count if i < 0 else i

func _storable(value: Variant, from_this: Block) -> bool:
	if value == null:
		from_this.function.error("There's nothing to put into '%s'. Fill in the value slot." % get_list_name())
		return false
	if value is Object:
		from_this.function.error("A list can't go inside another list in this game.")
		return false
	return true
#endregion


#region Layout
## Lays the board out for the current number of boxes and instances one slot per
## box. The instanced slots are never saved: they have no owner, so the scene
## file only ever holds the board's fixed parts.
func _rebuild() -> void:
	if not is_node_ready() or _slot_holder == null:
		return
	for old in _slot_holder.get_children():
		_slot_holder.remove_child(old)
		old.queue_free()
	_slots.clear()
	_name.text = String(get_list_name())
	_cursor.visible = false
	_ghost.modulate.a = 0.0
	_ghost_index.modulate.a = 0.0
	_ensure_slots(box_count())
	_refresh_marks()

## Adds boxes up to `count`, leaving the ones already there (and anything
## animating in them) alone, and stretches the board to fit.
func _ensure_slots(count: int) -> void:
	while _slots.size() < count:
		var i := _slots.size()
		var slot := SLOT_SCENE.instantiate() as ListSlot
		slot.position = Vector2(i * CELL, 0)
		_slot_holder.add_child(slot)
		slot.index_label.text = str(i)
		_slots.append(slot)
		if i < values.size():
			_fill_slot(i)
		else:
			_empty_slot(i)
	var rect := _board_rect(_slots.size())
	_board.position = rect.position
	_board.size = rect.size
	_legs.visible = standing
	(_legs.get_node(^"Left") as Control).position = Vector2(rect.position.x + rect.size.x * 0.18, rect.end.y)
	(_legs.get_node(^"Right") as Control).position = Vector2(rect.position.x + rect.size.x * 0.82 - 4.0, rect.end.y)
	var name_width := _name_width()
	_name.position = Vector2(-NAME_GAP - name_width, 0)
	_name.size = Vector2(name_width, CELL)
	# Kenney Mini's 29 px line puts its glyphs in its top half, so the caption
	# starts a little above the index row it labels, as the slots' indexes do.
	_caption.position = Vector2(-NAME_GAP - name_width, CELL - 5.0)
	_caption.size = Vector2(name_width, INDEX_ROW)

## The board for `count` boxes, in this node's space: the name column, the
## boxes, the index row, and a margin all round.
func _board_rect(count: int) -> Rect2:
	var left := -NAME_GAP - _name_width() - PAD
	var right := maxi(count, 1) * CELL + PAD
	return Rect2(left, -PAD_TOP, right - left, PAD_TOP + CELL + INDEX_ROW + PAD * 0.5)

## The name column: as wide as the list's name or the "index" caption.
func _name_width() -> float:
	var label := _name if _name != null else get_node_or_null(^"Name") as Label
	var caption := _caption if _caption != null else get_node_or_null(^"IndexCaption") as Label
	var width := 0.0
	for pair in [[label, String(get_list_name())], [caption, "index"]]:
		var l := pair[0] as Label
		var settings: LabelSettings = l.label_settings if l != null else null
		var font: Font = settings.font if settings != null else ThemeDB.fallback_font
		var font_size: int = settings.font_size if settings != null else ThemeDB.fallback_font_size
		width = maxf(width, font.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(width) + 2.0

## Shows the goal on the board: the wanted value faded in each empty box, a
## green badge with the wanted value on a box that holds something else, and a
## green or red card on each value the program wrote, by whether it's right.
func _refresh_marks() -> void:
	if _slots.is_empty():
		return
	for i in _slots.size():
		var slot := _slots[i]
		var has_value := i < values.size()
		var want_known := i < _target.size()
		var want: Variant = _target[i] if want_known else null

		slot.target_label.visible = _has_target and not has_value and want_known
		slot.target_label.text = _value_text(want) if want_known else ""

		var right := has_value and want_known and same(values[i], want)
		slot.wanted.visible = _has_target and has_value and want_known and not right
		slot.wanted_label.text = _value_text(want) if want_known else ""
		# A box past the end of the goal holds something that shouldn't be there.
		var extra := _has_target and has_value and not want_known

		slot.card.self_modulate = Color.WHITE
		if _has_target and has_value and _written.has(i):
			slot.card.self_modulate = TINT_RIGHT if right else TINT_WRONG
		elif extra:
			slot.card.self_modulate = TINT_WRONG

func _fill_slot(i: int) -> void:
	var slot := _slots[i]
	slot.cell.self_modulate = Color.WHITE
	slot.card.visible = true
	slot.card.modulate = Color.WHITE
	slot.value_label.text = _value_text(values[i])
	slot.index_label.modulate.a = 1.0

## A box past the end of the list: dim, no card, and no index, because there is
## no item there to number.
func _empty_slot(i: int) -> void:
	var slot := _slots[i]
	slot.cell.self_modulate = TINT_EMPTY
	slot.card.visible = false
	slot.value_label.text = ""
	slot.index_label.modulate.a = 0.0

func _value_text(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	return Core.to_python_repr(value) if not Engine.is_editor_hint() else str(value)
#endregion


#region Animation
func _anim_time() -> float:
	return minf(ANIM_TIME, Interpreter.current_delay)

func _flash(i: int, asked: Variant) -> void:
	_flash_card(_slots[i])
	# A negative index shows its own number on the index row for a moment, so -1
	# is seen landing on the last box.
	if typeof(asked) == TYPE_INT and asked < 0:
		var index := _slots[i].index_label
		index.text = str(asked)
		var tween := create_tween()
		tween.tween_interval(maxf(_anim_time(), Interpreter.current_delay))
		tween.tween_callback(func() -> void: index.text = str(i))

func _flash_card(slot: ListSlot, delay := 0.0) -> void:
	var t := _anim_time()
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay * t)
	tween.tween_property(slot.card, "position:y", slot.card_rest.y - 4.0, t * 0.35)
	tween.parallel().tween_property(slot.card, "modulate", TINT_FLASH, t * 0.35)
	tween.tween_property(slot.card, "position:y", slot.card_rest.y, t * 0.65)
	tween.parallel().tween_property(slot.card, "modulate", Color.WHITE, t * 0.65)

func _pop(slot: ListSlot) -> void:
	var t := _anim_time()
	var tween := create_tween()
	tween.tween_property(slot.card, "scale", Vector2.ONE * 1.25, t * 0.35)
	tween.parallel().tween_property(slot.card, "modulate", TINT_FLASH, t * 0.35)
	tween.tween_property(slot.card, "scale", Vector2.ONE, t * 0.65)
	tween.parallel().tween_property(slot.card, "modulate", Color.WHITE, t * 0.65)

func _drop(slot: ListSlot) -> void:
	var t := _anim_time()
	slot.card.position = slot.card_rest - Vector2(0, CELL * 0.6)
	slot.card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(slot.card, "position", slot.card_rest, t).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slot.card, "modulate:a", 1.0, t * 0.5)

## Remembers box `i` as where a value was just read, for _arrive().
func _remember(i: int) -> void:
	if Engine.is_editor_hint() or i >= _slots.size():
		return
	var slot := _slots[i]
	_sources.append({value = values[i], position = slot.to_global(slot.card_rest), list = self, index = i})
	if _sources.size() > SOURCES_KEPT:
		_sources.pop_front()

## Where, in `slot`'s own coordinates, a card carrying `value` should fly in from:
## the box that value was most recently read from, anywhere in the level. Null
## when it didn't come from a list (typed in, or worked out), so it drops in.
func _source_for(value: Variant, slot: ListSlot) -> Variant:
	for k in range(_sources.size() - 1, -1, -1):
		var source := _sources[k]
		if not is_instance_valid(source.list) or not same(source.value, value):
			continue
		if source.list == self and source.index == _slots.find(slot):
			return null  # read from and written to the same box: nothing to carry
		return slot.to_local(source.position)
	return null

## A written card arriving in its box: it flies from the board its value was
## read from, or drops in (pops, when it replaces a value in place).
func _arrive(slot: ListSlot, value: Variant, in_place := false) -> void:
	if Engine.is_editor_hint():
		return
	var from: Variant = _source_for(value, slot)
	if from == null:
		if in_place:
			_pop(slot)
		else:
			_drop(slot)
		return
	var flight := _flight_time()
	slot.card.z_index = 3  # over the walls and the robot while it crosses the room
	slot.card.modulate.a = 1.0
	slot.card.position = from
	var tween := create_tween()
	tween.tween_method(_arc.bind(slot.card, from, slot.card_rest), 0.0, 1.0, flight) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(slot):
			slot.card.z_index = 0
			slot.card.position = slot.card_rest)

## One point of a card's flight: a straight line from `from` to `to`, lifted into
## a shallow arc so it reads as carried rather than slid.
func _arc(k: float, card: Control, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(card):
		return
	var at := from.lerp(to, k)
	at.y -= sin(k * PI) * minf(24.0, from.distance_to(to) * 0.25)
	card.position = at

func _flight_time() -> float:
	return minf(FLIGHT_TIME, Interpreter.current_delay)

## Marks where an out-of-range index would have been: a red box just past the
## end, labelled with the index that was asked for.
func _show_ghost(i: int) -> void:
	if _ghost == null:
		return
	var at := clampi(i, 0, box_count() + GHOST_REACH - 1) if i >= 0 else 0
	_ghost.position = Vector2(at * CELL, 0)
	_ghost_index.position = Vector2(at * CELL, CELL - 5.0)
	_ghost_index.text = str(i)
	_ghost.modulate.a = 1.0
	_ghost_index.modulate.a = 1.0
#endregion
