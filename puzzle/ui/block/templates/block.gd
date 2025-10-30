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
@export var text_container: Container
@export_group("Components")
@export var drag: BlockDragComponent
@export var function: BlockFunctionComponent
@export var text: BlockTextComponent
@export var visual: BlockVisualComponent

var preview_type := PreviewType.NONE


static func construct(from_data: BlockData) -> Block:
	assert(from_data != null, "Constructing null data.")
	
	var scene := load(from_data.base_path) as PackedScene
	var block := scene.instantiate() as Block
	
	block.data = from_data.duplicate(true)
	block.name = block.data.name
	block.text.format()
	
	return block

func _ready() -> void:
	assert(data != null)
	
	if has_node(^"/root/Puzzle"):
		var puzzle := $"/root/Puzzle" as Puzzle
		function.notif_pushed.connect(puzzle._on_notif_pushed)
		function.errored.connect(puzzle._on_block_errored)
	
	text.format()
	
	if preview_type != PreviewType.NONE:
		if preview_type == PreviewType.DRAG:
			# MILD FIXME: Better on faster frame rates ;)
			await get_tree().process_frame
			drag.animate_preview()
		return
	
	function.initialize()

func _process(delta: float) -> void:
	if preview_type != PreviewType.NONE:
		return
	
	visual._update(delta)

func _gui_input(event: InputEvent) -> void:
	drag.handle_copying(event)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not data.draggable or Puzzle.is_running:
		return null
	
	set_drag_preview(drag.generate_preview())
	if data.toolbox:
		return drag.copy()
	
	visual.set_error(false)
	visible = false
	return self

func get_parent_block() -> Block:
	return Core.get_block(get_parent())

func get_parent_matching(condition: Callable, include_self := true) -> Block:
	if include_self and condition.call(self):
		return self
	
	var parent := get_parent_block()
	while parent != null:
		if condition.call(parent):
			return parent
		parent = parent.get_parent_block()
	return null

func orphan() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
