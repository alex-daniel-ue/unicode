@abstract
class_name Block
extends VBoxContainer


@warning_ignore("unused_signal")
signal errored(message: String)

enum PreviewType { NONE, DRAG, DROP }

const DROP_SOUND := preload("res://audio/block_drop.mp3")

static var IS_SOLID := func(block: Block) -> bool:
	return not block is SocketBlock
static var IS_NESTED := func(block: Block) -> bool:
	return block is NestedBlock

@export var data: BlockData
@export_group("Children")
@export var text_container: Container
@export_group("Components")
@export var drag: BlockDragComponent
@export var function: BlockFunctionComponent
@export var text: BlockTextComponent
@export var visual: BlockVisualComponent

var preview_type := PreviewType.NONE
var display := false


static func construct(from_data: BlockData) -> Block:
	assert(from_data != null, "Constructing null data.")
	
	var scene := load(from_data.base_path) as PackedScene
	var block := scene.instantiate() as Block
	
	block.data = from_data.deep_copy()
	block.name = block.data.name
	block.text.format()
	
	return block

func _ready() -> void:
	assert(data != null)
	
	text.format()
	if display:
		visual.apply_immediately()
		return
	
	if preview_type != PreviewType.NONE:
		if preview_type == PreviewType.DRAG:
			drag.animate_preview.call_deferred()
		return
	
	function.initialize()

func _process(delta: float) -> void:
	if display or preview_type != PreviewType.NONE:
		return
	
	visual._update(delta)

func _gui_input(event: InputEvent) -> void:
	drag.handle_copying(event)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if display or not data.draggable or Interpreter.is_running:
		return null
	
	var preview := drag.generate_preview()
	set_drag_preview(preview)
	Core.current_drag_preview = preview
	
	if data.toolbox:
		return drag.copy()
	
	visual.set_error(false)
	visible = false
	return self

func get_all_blocks(include_self := false) -> Array[Block]:
	var result: Array[Block]
	if include_self:
		result.append(self)
	for param in text.get_blocks():
		result.append_array(param.get_all_blocks(true))
	return result

func get_parent_block() -> Block:
	return Core.get_block(get_parent())

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

func is_trashable() -> bool:
	if not data.trashable:
		return false
	
	for block in get_all_blocks():
		if not block.data.trashable:
			return false
	
	return true

func is_pinned() -> bool:
	if not data.trashable:
		return true
	
	for param in text.get_blocks():
		if param.is_pinned():
			return true
	
	return false
