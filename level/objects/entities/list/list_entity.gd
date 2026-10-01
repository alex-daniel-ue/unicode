@tool
class_name ListEntity
extends Node2D

## A list that lives in a room: a shelf of cubbies, one per tile, each holding a
## bag with its value printed on it. The level makes it; the student reads and
## changes it through blocks, and the room shows every change.
##
## One shelf per room. A level puts a shelf in every room that needs the list,
## all with the same list_name and each with its own room_index, and the name
## block a student drags finds the shelf of the room that's running (find()).
## So every room's contents are on screen before Play, the way every room's walls
## are, and nothing has to move between rooms. A level with a single shelf of a
## name uses it in every room; give it a Resettable tracking `values` if its
## contents should differ per room.
##
## The operations are called by list_functions.gd with the calling block last,
## the way robot.gd's are, and pace themselves with Interpreter.step(). The
## errors are raised here, in Python's terms, because only the list knows its
## own name, kind and length.
##
## Author it by instancing list_entity.tscn under Visuals, snapping it to the
## tile grid (its origin is the top-left corner of cubby 0) and filling in
## `values`. The scene holds the shelf's parts; this script lays them out for the
## cubby count and instances one list_slot.tscn per cubby. Art lives in the two
## scenes and in art/.

enum Kind { LIST, TUPLE, SET }

const GROUP := &"list_entity"
const SCENE_PATH := "res://level/objects/entities/list/list_entity.tscn"
const SLOT_SCENE := preload("res://level/objects/entities/list/list_slot.tscn")
const REPORTER_TEMPLATE := "res://puzzle/blocks/lists/list_reporter.tres"

## One cubby per tile, so a robot standing under cubby i is standing at index i.
const CELL := 32.0
const RAIL := 20.0
const BRACKET_W := 10.0
## How far above the shelf the for-each pointer reaches.
const POINTER_REACH := 11.0
## Where a name tag above the shelf starts: clear of the pointer below it.
const TAG_ABOVE_Y := -CELL - 10.0
## Longest a bag takes to fly from one shelf to another.
const FLIGHT_TIME := 0.45
## Longest an animation runs; slower speeds still leave a still frame to read.
const ANIM_TIME := 0.25
## The ghost cubby for an out-of-range index is drawn at most this far past the end.
const GHOST_REACH := 3

## Tints over the art. The art itself is in art/ and the two scenes.
const TINT_EMPTY := Color(0.62, 0.62, 0.62)
const TINT_FLASH := Color("#ffd166")
const TINT_ERROR := Color("#fb7185")
## A bag the program wrote that matches the goal, or doesn't.
const TINT_RIGHT := Color(0.78, 1.0, 0.8)
const TINT_WRONG := Color(1.0, 0.62, 0.62)

## What students read, and what the name block says. Empty means the node's name.
@export var list_name: StringName = &"":
	set(value):
		list_name = value
		_rebuild()
		update_configuration_warnings()
@export var kind := Kind.LIST:
	set(value):
		kind = value
		if kind == Kind.SET:
			values = normalized(values)
		_rebuild()
## Which room this shelf belongs to, counted from 0 like Resettable's rooms, so
## Room 1 is 0. Ignored when the level has only one shelf with this name.
@export var room_index := 0
@export var values: Array = []:
	set(value):
		values = normalized(value) if kind == Kind.SET else value
		_rebuild()
## Cubbies drawn. A list the program appends to needs spare ones, since a full
## shelf is an error. 0 draws exactly as many as there are values.
@export_range(0, 30) var capacity := 0:
	set(value):
		capacity = value
		_rebuild()
## Puts the name tag above the shelf instead of to its left: for shelves along a
## hallway wall, where the next shelf leaves no room at the side.
@export var tag_above := false:
	set(value):
		tag_above = value
		_rebuild()

## The last few cubbies values were read from, anywhere in the level, newest
## last: where a bag flies from when that value goes into a list. A few rather
## than one, because a program often reads something else in between, as in
## `if b != item -1 of tidy: append b to tidy`. Cleared at each run.
static var _sources: Array[Dictionary] = []
const SOURCES_KEPT := 4

var _initial: Array = []
var _slots: Array[ListSlot] = []
## What a ListGoal wants this list to end up as, shown on the shelf so the goal
## is on screen the way a flag is. Empty and unused without a goal.
var _target: Array = []
var _has_target := false
## What the program has written this run: positions for a list or tuple, values
## for a set. Only written bags are marked right or wrong, so a list that starts
## off different from its goal (AR-6's lockers) isn't red before anything runs.
var _written: Array = []

@onready var _back: Sprite2D = get_node_or_null(^"Back")
@onready var _tag: Label = get_node_or_null(^"Tag")
@onready var _open: Line2D = get_node_or_null(^"OpenBracket")
@onready var _close: Line2D = get_node_or_null(^"CloseBracket")
@onready var _slot_holder: Node2D = get_node_or_null(^"Slots")
@onready var _glass: Sprite2D = get_node_or_null(^"Glass")
@onready var _pointer: Polygon2D = get_node_or_null(^"Pointer")
@onready var _ghost: Sprite2D = get_node_or_null(^"Ghost")
@onready var _ghost_index: Label = get_node_or_null(^"GhostIndex")


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	_initial = values.duplicate(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PATH_RENAMED and list_name.is_empty():
		_rebuild()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_node_or_null(^"Slots") == null:
		warnings.append("This is the ListEntity script on its own. Instance list_entity.tscn instead; the shelf's parts live in the scene.")
	var shown := String(get_list_name())
	if not shown.is_valid_ascii_identifier():
		warnings.append("'%s' isn't a name Python would accept, and students will read it as one." % shown)
	return warnings


#region Queries
func get_list_name() -> StringName:
	return list_name if not list_name.is_empty() else StringName(name)

## Python's name for this kind: list, tuple or set.
func kind_name() -> String:
	return ["list", "tuple", "set"][kind]

## The values as Python writes them: [1, 2], (1,), {1, 2}, set().
func repr() -> String:
	return repr_of(values)

## What the level started this list with, as Python writes it.
func initial_repr() -> String:
	return repr_of(_initial)

func repr_of(items: Array) -> String:
	var parts := PackedStringArray()
	for item: Variant in items:
		parts.append(Core.to_python_repr(item))
	match kind:
		Kind.TUPLE:
			return "(" + ", ".join(parts) + ("," if parts.size() == 1 else "") + ")"
		Kind.SET:
			return "set()" if parts.is_empty() else "{" + ", ".join(parts) + "}"
	return "[" + ", ".join(parts) + "]"

## True when the contents equal `expected` in Python's terms: 3 and "3" differ,
## 3 and 3.0 don't, and a set ignores order and repeats.
func matches(expected: Array) -> bool:
	var want: Array = normalized(expected) if kind == Kind.SET else expected
	if want.size() != values.size():
		return false
	for i in want.size():
		if not same(values[i], want[i]):
			return false
	return true

func cubby_count() -> int:
	return maxi(maxi(values.size(), capacity), _target.size())

## Called by a ListGoal: what this list should end up holding.
func set_target(expected: Array) -> void:
	_has_target = true
	_target = normalized(expected) if kind == Kind.SET else expected.duplicate()
	_rebuild()

## The whole shelf in global coordinates, name tag and pointer included. Worked
## out from the exported values rather than measured from the nodes, so it is
## right before _ready() has laid the shelf out, which is when the editor's
## LevelCamera measures a level. LevelCamera.node_bounds() asks for it.
func get_global_bounds() -> Rect2:
	var width := cubby_count() * CELL
	var left := -BRACKET_W - 6.0 - _tag_width()
	var right := width + BRACKET_W + 2.0
	var top := -POINTER_REACH
	if tag_above:
		left = -BRACKET_W - 2.0
		right = maxf(right, left + _tag_width())
		top = TAG_ABOVE_Y
	var bottom := CELL + _rail() + 2.0
	return global_transform * Rect2(left, top, right - left, bottom - top)

## Among every shelf of this name in the level, the one that hands out the name
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

## A new shelf from the scene, for code that needs one (the level checks).
static func create() -> ListEntity:
	return (load(SCENE_PATH) as PackedScene).instantiate() as ListEntity

## The shelf a block means by `p_name` right now: the only one with that name, or
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
static func reporter_data(p_name: StringName, p_kind := Kind.LIST) -> BlockData:
	var data := (load(REPORTER_TEMPLATE) as BlockData).deep_copy()
	var kind_word: String = ["list", "tuple", "set"][p_kind]
	# Unique per list: the assistant's block doc is keyed by name.
	data.name = "List_%s" % p_name
	data.text = String(p_name)
	data.syntax = String(p_name)
	data.description = (
		"The %s named %s, shown on its shelf in the room. Drop it into any block that needs a list. It's the same as typing its name."
		% [kind_word, p_name]
	)
	data.func_entity_name = p_name
	return data

func make_reporter_data() -> BlockData:
	return reporter_data(get_list_name(), kind)

## Sets hold each value once, and this game keeps them in order so the shelf
## reads the way Python prints a set of small numbers.
static func normalized(items: Array) -> Array:
	var result: Array = []
	for item: Variant in items:
		var seen := false
		for kept: Variant in result:
			if same(item, kept):
				seen = true
				break
		if not seen:
			result.append(item)
	result.sort_custom(_before)
	return result

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

static func _before(a: Variant, b: Variant) -> bool:
	var rank_a := _sort_rank(a)
	var rank_b := _sort_rank(b)
	if rank_a != rank_b:
		return rank_a < rank_b
	if rank_a == 2:
		return str(a) < str(b)
	return a < b

static func _sort_rank(value: Variant) -> int:
	match typeof(value):
		TYPE_BOOL: return 0
		TYPE_INT, TYPE_FLOAT: return 1
	return 2
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
	if kind == Kind.TUPLE:
		_flash_glass()
		from_this.function.error("'%s' is a tuple, so its items can't be changed." % get_list_name())
		return
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
		_flash_bag(_slots[i])
	await Interpreter.step(from_this)
	return values.size()

## append {value} to {list}
func append_value(value: Variant, from_this: Block) -> void:
	match kind:
		Kind.TUPLE:
			_flash_glass()
			from_this.function.error("'%s' is a tuple, so it can't grow. Tuples have no append." % get_list_name())
			return
		Kind.SET:
			from_this.function.error("'%s' is a set. Sets use add, not append." % get_list_name())
			return
	if not _storable(value, from_this) or not _has_room(from_this):
		return
	values.append(value)
	var i := values.size() - 1
	_fill_slot(i)
	_written.append(i)
	_arrive(_slots[i], value)
	_refresh_marks()
	await Interpreter.step(from_this)

## add {value} to {set}
func add_value(value: Variant, from_this: Block) -> void:
	match kind:
		Kind.LIST:
			from_this.function.error("'%s' is a list. Lists use append, not add." % get_list_name())
			return
		Kind.TUPLE:
			_flash_glass()
			from_this.function.error("'%s' is a tuple, so it can't grow. Tuples have no add." % get_list_name())
			return
	if not _storable(value, from_this):
		return

	for i in values.size():
		if same(values[i], value):
			# Already there: a set keeps one of each, so the new one bounces off.
			_bounce_off(i)
			await Interpreter.step(from_this)
			return

	if not _has_room(from_this):
		return
	_written.append(value)
	var grown := values.duplicate()
	grown.append(value)
	values = grown  # re-sorts and redraws
	for i in values.size():
		if same(values[i], value):
			_arrive(_slots[i], value)
			break
	await Interpreter.step(from_this)

## {value} in {list}
func contains(value: Variant, from_this: Block) -> bool:
	var found := -1
	for i in values.size():
		if same(values[i], value):
			found = i
			break
	if kind == Kind.SET:
		# A set jumps straight to the value; a list or tuple looks at each in turn.
		if found >= 0:
			_flash_bag(_slots[found])
	else:
		var last := found if found >= 0 else values.size() - 1
		for i in last + 1:
			_flash_bag(_slots[i], float(i) / maxf(1.0, last + 1.0))
	await Interpreter.step(from_this)
	return found >= 0

## Draws the for-each pointer over cubby `i`; a negative index hides it.
func point_at(i: int) -> void:
	if _pointer == null:
		return
	_pointer.visible = i >= 0 and i < _slots.size()
	if _pointer.visible:
		_pointer.position = Vector2(i * CELL + CELL / 2.0, 0)
		if i < values.size():
			_remember(i)

func flash_name() -> void:
	if _tag == null or Engine.is_editor_hint():
		return
	var tween := create_tween()
	tween.tween_property(_tag, "modulate", TINT_FLASH, _anim_time() * 0.4)
	tween.tween_property(_tag, "modulate", Color.WHITE, _anim_time() * 0.6)

## Back to the contents the level was authored with. Redraws, which also clears
## the pointer and any ghost cubby left by the last run.
func restore() -> void:
	_written.clear()
	_sources.clear()
	values = _initial.duplicate(true)
#endregion


#region Checks shared by the operations
## The index as a position in `values`, or null after raising the error.
func _checked_index(index: Variant, from_this: Block, what: String) -> Variant:
	var list_label := get_list_name()
	if kind == Kind.SET:
		from_this.function.error("'%s' is a set. Sets have no positions, so there's no item %s." % [list_label, Core.to_python_repr(index)])
		return null
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
				if what == "set item" and kind == Kind.LIST and count == 0 else ""
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

func _has_room(from_this: Block) -> bool:
	if values.size() < cubby_count():
		return true
	from_this.function.error(
		"'%s' is full: its shelf has %d cubbies. Is something being added to the list a loop is going through?"
		% [get_list_name(), cubby_count()]
	)
	return false
#endregion


#region Layout
## Lays the scene's parts out for the current cubby count and kind, and
## instances one slot per cubby. The instanced slots are never saved: they have
## no owner, so the scene file only ever holds the shelf's fixed parts.
func _rebuild() -> void:
	if not is_node_ready() or _slot_holder == null:
		return

	for old in _slot_holder.get_children():
		_slot_holder.remove_child(old)
		old.queue_free()
	_slots.clear()

	var count := cubby_count()
	var width := count * CELL
	var rail := _rail()

	_back.position = Vector2(-BRACKET_W - 2.0, -2.0)
	_stretch(_back, Vector2(width + BRACKET_W * 2.0 + 4.0, CELL + rail + 4.0))

	# Reads as the Python that makes the list: `scores = (70, 82, 75)`.
	var tag_width := _tag_width()
	_tag.text = _tag_text()
	_tag.size = Vector2(tag_width, CELL)
	if tag_above:
		_tag.position = Vector2(-BRACKET_W, TAG_ABOVE_Y)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_tag.position = Vector2(-BRACKET_W - 6.0 - tag_width, 0)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bracket_height := CELL + rail - 4.0
	_open.points = _bracket_points(bracket_height)
	_open.position = Vector2(-BRACKET_W + 1.0, 2.0)
	_close.points = _bracket_points(bracket_height)
	_close.position = Vector2(width + BRACKET_W - 1.0, 2.0)

	_glass.visible = kind == Kind.TUPLE and count > 0
	_stretch(_glass, Vector2(width, CELL))

	_pointer.visible = false
	_ghost.modulate.a = 0.0
	_ghost_index.modulate.a = 0.0

	for i in count:
		var slot := SLOT_SCENE.instantiate() as ListSlot
		slot.position = Vector2(i * CELL, 0)
		_slot_holder.add_child(slot)
		slot.index_label.text = str(i)
		slot.index_label.visible = kind != Kind.SET
		_slots.append(slot)
		if i < values.size():
			_fill_slot(i)
		else:
			_empty_slot(i)
	_refresh_marks()

## Shows the goal on the shelf: a faded bag in each empty cubby the goal wants
## filled, the wanted value in the corner of a cubby that holds something else,
## and a green or red tint on each bag the program wrote, by whether it's right.
## Lists and tuples compare cubby by cubby; a set compares by value, since its
## positions shift as it grows.
func _refresh_marks() -> void:
	if _slots.is_empty():
		return
	var missing: Array = []
	if kind == Kind.SET:
		for wanted: Variant in _target:
			if not values.any(func(v: Variant) -> bool: return same(v, wanted)):
				missing.append(wanted)

	for i in _slots.size():
		var slot := _slots[i]
		var has_value := i < values.size()
		var want: Variant = null
		var want_known := false
		if kind == Kind.SET:
			var j := i - values.size()
			if not has_value and j < missing.size():
				want = missing[j]
				want_known = true
		elif i < _target.size():
			want = _target[i]
			want_known = true

		slot.target.visible = _has_target and not has_value and want_known
		slot.target_label.text = _value_text(want) if want_known else ""

		var right := false
		if has_value:
			right = _target.any(func(t: Variant) -> bool: return same(t, values[i])) \
					if kind == Kind.SET else (want_known and same(values[i], want))
		slot.wanted.visible = _has_target and has_value and kind != Kind.SET and want_known and not right
		slot.wanted.text = _value_text(want) if want_known else ""

		var written := false
		if has_value:
			written = _written.any(func(w: Variant) -> bool: return same(w, values[i])) \
					if kind == Kind.SET else _written.has(i)
		slot.bag.self_modulate = Color.WHITE
		if _has_target and written:
			slot.bag.self_modulate = TINT_RIGHT if right else TINT_WRONG

func _fill_slot(i: int) -> void:
	var slot := _slots[i]
	slot.cubby.modulate = Color.WHITE
	slot.bag.visible = true
	slot.bag.modulate = Color.WHITE
	slot.value_label.text = _value_text(values[i])
	slot.index_label.modulate.a = 1.0

## A cubby past the end of the list: dim, no bag, and no index, because there is
## no item there to number.
func _empty_slot(i: int) -> void:
	var slot := _slots[i]
	slot.cubby.modulate = TINT_EMPTY
	slot.bag.visible = false
	slot.value_label.text = ""
	slot.index_label.modulate.a = 0.0

func _rail() -> float:
	return 0.0 if kind == Kind.SET else RAIL

func _tag_text() -> String:
	return "%s =" % get_list_name()

## The tag's width in its own theme's font. Measured from the theme rather than
## from the Label, because the Label can't resolve its theme outside the tree,
## and get_global_bounds() has to work before _ready().
func _tag_width() -> float:
	# Before _ready() the @onready reference is still empty, but the scene's Tag
	# node already exists and carries its theme.
	var tag := _tag if _tag != null else get_node_or_null(^"Tag") as Label
	var theme: Theme = tag.theme if tag != null else null
	var font: Font = theme.get_font(&"font", &"Label") if theme != null else ThemeDB.fallback_font
	var font_size: int = theme.get_font_size(&"font_size", &"Label") if theme != null else ThemeDB.fallback_font_size
	var outline: int = theme.get_constant(&"outline_size", &"RoomLabel") if theme != null else 0
	return font.get_string_size(_tag_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + outline + 2.0

## One end of the shelf, `[`, `(` or `{`, from its outer top corner. The closing
## end is the same line mirrored by the scene.
func _bracket_points(height: float) -> PackedVector2Array:
	var w := BRACKET_W - 3.0
	var h := height
	var points := PackedVector2Array()
	match kind:
		Kind.LIST:
			points = [Vector2(w, 0), Vector2(0, 0), Vector2(0, h), Vector2(w, h)]
		Kind.TUPLE:
			for step in 9:
				var angle := PI / 2.0 + PI * step / 8.0
				points.append(Vector2(w + cos(angle) * w, h / 2.0 - sin(angle) * h / 2.0))
		Kind.SET:
			points = [Vector2(w, 0), Vector2(w * 0.45, h * 0.06), Vector2(w * 0.45, h * 0.44),
				Vector2(0, h * 0.5), Vector2(w * 0.45, h * 0.56), Vector2(w * 0.45, h * 0.94), Vector2(w, h)]
	return points

## Sizes a sprite to `rect_size` pixels, whatever its texture's size.
func _stretch(sprite: Sprite2D, rect_size: Vector2) -> void:
	sprite.scale = rect_size / sprite.texture.get_size()

func _value_text(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	return Core.to_python_repr(value) if not Engine.is_editor_hint() else str(value)
#endregion


#region Animation
func _anim_time() -> float:
	return minf(ANIM_TIME, Interpreter.current_delay)

func _flash(i: int, asked: Variant) -> void:
	_flash_bag(_slots[i])
	# A negative index shows its own number on the rail for a moment, so -1 is
	# seen landing on the last cubby.
	if typeof(asked) == TYPE_INT and asked < 0:
		var index := _slots[i].index_label
		index.text = str(asked)
		var tween := create_tween()
		tween.tween_interval(maxf(_anim_time(), Interpreter.current_delay))
		tween.tween_callback(func() -> void: index.text = str(i))

func _flash_bag(slot: ListSlot, delay := 0.0) -> void:
	var t := _anim_time()
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay * t)
	tween.tween_property(slot.bag, "position:y", slot.bag_rest.y - 4.0, t * 0.35)
	tween.parallel().tween_property(slot.bag, "modulate", TINT_FLASH, t * 0.35)
	tween.tween_property(slot.bag, "position:y", slot.bag_rest.y, t * 0.65)
	tween.parallel().tween_property(slot.bag, "modulate", Color.WHITE, t * 0.65)

func _pop(slot: ListSlot) -> void:
	var t := _anim_time()
	var tween := create_tween()
	tween.tween_property(slot.bag, "scale", Vector2.ONE * 1.25, t * 0.35)
	tween.parallel().tween_property(slot.bag, "modulate", TINT_FLASH, t * 0.35)
	tween.tween_property(slot.bag, "scale", Vector2.ONE, t * 0.65)
	tween.parallel().tween_property(slot.bag, "modulate", Color.WHITE, t * 0.65)

func _drop(slot: ListSlot) -> void:
	var t := _anim_time()
	slot.bag.position = slot.bag_rest - Vector2(0, CELL * 0.6)
	slot.bag.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(slot.bag, "position", slot.bag_rest, t).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slot.bag, "modulate:a", 1.0, t * 0.5)

## A repeat added to a set: a copy lands on its twin, bounces off and fades. The
## copy flies in from where the value was read, when that's known.
func _bounce_off(i: int) -> void:
	var slot := _slots[i]
	var copy := slot.bag.duplicate() as Sprite2D
	copy.self_modulate = Color.WHITE
	slot.add_child(copy)
	var from: Variant = _source_for(values[i], slot)
	var t := _anim_time()
	var tween := create_tween()
	if from != null:
		var flight := _flight_time()
		copy.z_index = 3
		copy.position = from
		tween.tween_method(_arc.bind(copy, from, slot.bag_rest - Vector2(0, 6)), 0.0, 1.0, flight * 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t = flight * 0.3
	else:
		copy.position = slot.bag_rest - Vector2(0, CELL * 0.6)
		tween.tween_property(copy, "position:y", slot.bag_rest.y - 6.0, t * 0.4)
	tween.tween_property(copy, "position:y", slot.bag_rest.y - CELL, t * 0.6)
	tween.parallel().tween_property(copy, "modulate:a", 0.0, t * 0.6)
	tween.tween_callback(copy.queue_free)
	_flash_bag(slot, 0.4)

## Remembers cubby `i` as where a value was just read, for _arrive().
func _remember(i: int) -> void:
	if Engine.is_editor_hint() or i >= _slots.size():
		return
	var slot := _slots[i]
	_sources.append({value = values[i], position = slot.to_global(slot.bag_rest), list = self, index = i})
	if _sources.size() > SOURCES_KEPT:
		_sources.pop_front()

## Where, in `slot`'s own coordinates, a bag carrying `value` should fly in from:
## the cubby that value was most recently read from, anywhere in the level. Null
## when it didn't come from a shelf (typed in, or worked out), so it drops in.
func _source_for(value: Variant, slot: ListSlot) -> Variant:
	for k in range(_sources.size() - 1, -1, -1):
		var source := _sources[k]
		if not is_instance_valid(source.list) or not same(source.value, value):
			continue
		if source.list == self and source.index == _slots.find(slot):
			return null  # read from and written to the same cubby: nothing to carry
		return slot.to_local(source.position)
	return null

## A written bag arriving in its cubby: it flies from the shelf its value was
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
	slot.bag.z_index = 3  # over the walls and the robot while it crosses the room
	slot.bag.modulate.a = 1.0
	slot.bag.position = from
	var tween := create_tween()
	tween.tween_method(_arc.bind(slot.bag, from, slot.bag_rest), 0.0, 1.0, flight) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(slot):
			slot.bag.z_index = 0
			slot.bag.position = slot.bag_rest)

## One point of a bag's flight: a straight line from `from` to `to`, lifted into
## a shallow arc so it reads as carried rather than slid.
func _arc(k: float, bag: Sprite2D, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(bag):
		return
	var at := from.lerp(to, k)
	at.y -= sin(k * PI) * minf(24.0, from.distance_to(to) * 0.25)
	bag.position = at

func _flight_time() -> float:
	return minf(FLIGHT_TIME, Interpreter.current_delay)

func _flash_glass() -> void:
	if _glass == null or Engine.is_editor_hint():
		return
	var rest := _glass.modulate
	var tween := create_tween()
	tween.tween_property(_glass, "modulate", Color(TINT_ERROR, 0.6), _anim_time() * 0.3)
	tween.tween_property(_glass, "modulate", rest, _anim_time() * 0.7)

## Marks where an out-of-range index would have been: a red cubby just past the
## end, labelled with the index that was asked for.
func _show_ghost(i: int) -> void:
	if _ghost == null:
		return
	var at := clampi(i, 0, cubby_count() + GHOST_REACH - 1) if i >= 0 else 0
	_ghost.position = Vector2(at * CELL + 1.0, 1.0)
	_ghost_index.position = Vector2(at * CELL, CELL - 1.0)
	_ghost_index.text = str(i)
	_ghost.modulate.a = 0.55
	_ghost_index.modulate.a = 1.0
#endregion
