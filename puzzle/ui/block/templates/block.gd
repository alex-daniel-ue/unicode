@abstract
class_name Block
extends VBoxContainer
## A block: its BlockData plus the scene that draws it. Block.construct() builds
## one from data; the scene (statement, nested, cap, expression or value block)
## is named by the data's base_path.
##
## Four components do the work: text builds the label and the slots, function
## runs the block, visual handles its colour, and drag handles copying and
## dragging.

enum PreviewType { NONE, DRAG, DROP }

@export var data: BlockData
## Blocks to plug into this block's own slots, authored as scene children instead
## of as a chain of inline BlockData copies.
##
## text.format() tears text_container down and rebuilds it from data.text_blocks,
## so a block parked directly in a slot in the .tscn would be deleted before it
## ever runs. The blocks under here are parked outside that container instead,
## and text.format() plugs them in after the rebuild, in child order, one per
## receptive slot. Whatever format() does to the slots, the fills survive it.
##
## Point it at any plain Node, inside this block or beside it. Its Block children
## are ordinary scene nodes, so a fill that calls the robot can have `object` set
## by NodePath like any other authored block, and a fill can carry fills of its own.
@export var preset_fills: Node

@export_group("Children")
@export var text_container: Container

@export_group("Components")
@export var drag: BlockDragComponent
@export var function: BlockFunctionComponent
@export var text: BlockTextComponent
@export var visual: BlockVisualComponent

## Set on the copies drag and drop shows while a block moves.
var preview_type := PreviewType.NONE
## A picture of a block (a guide's, the brief's, the menu's demo): drawn like the
## real one, but it doesn't run, animate or move.
var is_picture := false


static func construct(from_data: BlockData) -> Block:
	assert(from_data != null, "Constructing null data.")
	var scene := load(from_data.base_path) as PackedScene
	var block := scene.instantiate() as Block
	block.data = from_data.deep_copy()
	block.name = block.data.name
	block.text.format()
	return block


## A block that stands in a program (a statement, a loop), as opposed to one
## that goes in a slot.
static func is_solid(block: Block) -> bool:
	return not block is SocketBlock


func _ready() -> void:
	assert(data != null)

	# A slot block inside a picture is part of the picture too. It's built, and
	# ready, before its parent says it's a picture, so it asks: otherwise an
	# Ahead Is in a picture looks for a robot to talk to, outside any level.
	if not is_picture and _in_picture():
		is_picture = true
	text.format()
	if is_picture:
		visual.apply_immediately()
		return

	if preview_type != PreviewType.NONE:
		if preview_type == PreviewType.DRAG:
			drag.animate_preview.call_deferred()
		return

	function.initialize()


func _process(delta: float) -> void:
	if is_picture or preview_type != PreviewType.NONE:
		return
	visual.update_color(delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and not shows_at(get_global_transform() * (event as InputEventMouse).position):
		return
	drag.handle_copying(event)


func _get_drag_data(at_position: Vector2) -> Variant:
	if is_picture or not data.draggable or Interpreter.is_running:
		return null
	# Pressed inside the block's box but not on the block: the canvas showing
	# beside narrower blocks or inside a loop. That pans (PuzzleCanvas), it
	# doesn't pick the whole stack up.
	if not shows_at(get_global_transform() * at_position):
		return null

	set_drag_preview(drag.generate_preview())
	SfxPlayer.play(SfxPlayer.BLOCK_PICKED_UP)

	if data.toolbox:
		return drag.copy()

	visual.set_error(false)
	visible = false
	return self


## Whether `point` (global) is on this block as it's drawn, not merely inside
## its box. A block is drawn as its whole box; a loop and begin aren't (see
## their overrides).
func shows_at(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


## The blocks in this block's slots, and theirs, depth first.
func get_all_blocks(include_self := false) -> Array[Block]:
	var result: Array[Block]
	if include_self:
		result.append(self)
	for param in text.get_blocks():
		result.append_array(param.get_all_blocks(true))
	return result


func get_parent_block() -> Block:
	return Core.get_block(get_parent())


## The nearest block, from this one up, for which `condition` is true.
func get_parent_matching(condition: Callable, include_self := true) -> Block:
	var current := self if include_self else get_parent_block()
	while current != null:
		if condition.call(current):
			return current
		current = current.get_parent_block()
	return null


func orphan() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)


## Whether the trash takes this block: it and every block in it can be trashed.
func is_trashable() -> bool:
	if not data.trashable:
		return false
	for block in get_all_blocks():
		if not block.data.trashable:
			return false
	return true


## Whether Trash all must keep this block: it, or a block in one of its slots,
## was placed by the level.
func is_pinned() -> bool:
	if not data.trashable:
		return true
	for param in text.get_blocks():
		if param.is_pinned():
			return true
	return false


func _in_picture() -> bool:
	var node := get_parent()
	while node != null:
		if node is Block and (node as Block).is_picture:
			return true
		node = node.get_parent()
	return false
