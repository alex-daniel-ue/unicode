@tool
@abstract
class_name RoomEntity
extends Node2D
## Something in a room that blocks read and change: a list's board, a
## dictionary's board, a text file or a terminal.
##
## A level puts one in every room that needs it, all with the same name and each
## with its own room_index, so every room's contents are on screen before Play
## and nothing has to move between rooms. A block finds the one in the room that
## is running (find_named()). Every run starts by putting them all back as the
## level made them (restore()), and each stays as the run left it, so a student
## can read what went wrong.

const GROUP := &"room_entity"
## The font the drawn ones (dictionaries, files, terminals) write in.
const FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const FONT_SIZE := 16
## A row or line glows this colour as a block reads or writes it.
const FLASH_COLOR := Color(1.0, 0.82, 0.3)

## Which room this belongs to, counted from 0 like Resettable's rooms, so Room 1
## is 0. Ignored when the level has only one of this kind and name.
@export var room_index := 0


## The one of `kind` named `entity_name` that a block means right now: the only
## one in the level, or the one in the room that is running. An empty name
## matches any.
static func find_named(kind: Script, entity_name: StringName) -> RoomEntity:
	var level := Game.level
	if level == null or not level.is_inside_tree():
		return null
	var named: Array[RoomEntity] = []
	for node in level.get_tree().get_nodes_in_group(GROUP):
		var entity := node as RoomEntity
		if entity == null or entity.get_script() != kind or not level.is_ancestor_of(entity):
			continue
		if entity_name.is_empty() or entity.get_entity_name() == entity_name:
			named.append(entity)
	if named.size() == 1:
		return named[0]
	for entity in named:
		if entity.room_index == level.current_room:
			return entity
	return null


static func text_width(text: String, font_size := FONT_SIZE) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Only a level's are ones a program can reach: a guide's picture of one is
	# just a picture, and a run mustn't restore it.
	if Game.level != null and Game.level.is_ancestor_of(self):
		add_to_group(GROUP)


## The name a program uses for it, as its name block shows it.
@abstract func get_entity_name() -> StringName


## Back to what the level made, before a run.
@abstract func restore() -> void


## The whole thing in global coordinates, worked out from its contents rather
## than measured from its nodes, so it is right before it has been laid out or
## drawn: the editor's LevelCamera measures a level from its own _ready().
@abstract func get_global_bounds() -> Rect2


## Among every one of this kind and name in the level, the one that hands out
## the name block: the lowest room_index, then the first in the tree.
func is_canonical() -> bool:
	var best: RoomEntity = null
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as RoomEntity
		if other == null or other.get_script() != get_script() or other.get_entity_name() != get_entity_name():
			continue
		if best == null or other.room_index < best.room_index:
			best = other
	return best == self


## A rounded box with a 2 px edge, the way the drawn ones draw their parts.
func _draw_box(rect: Rect2, fill: Color, edge: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
