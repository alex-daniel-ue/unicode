class_name BlockDragComponent
extends BlockBaseComponent
## Picking a block up: the see-through preview that follows the pointer, and
## the copy that a drag from the Toolbox, or a right-click, hands out.

const DRAG_CENTER_DURATION := 0.5
const DRAG_PREVIEW_TRANSPARENCY := 0.5
## Stands in for a nested block's body in its drag preview: "3 blocks...".
const BODY_SUMMARY := preload("res://puzzle/ui/block/body_summary.tres")


## The preview that follows the pointer: a fresh block built from the same data,
## with the body of a nested block summed up rather than drawn.
func generate_preview() -> Control:
	var drag_preview_container := Control.new()
	drag_preview_container.name = "DragPreviewContainer"

	var drag_preview := Block.construct(base.data)
	drag_preview.preview_type = Block.PreviewType.DRAG
	drag_preview_container.add_child(drag_preview)
	PuzzleCanvas.drag_preview = drag_preview

	drag_preview.modulate.a = DRAG_PREVIEW_TRANSPARENCY
	drag_preview.position = -base.get_local_mouse_position()

	if base is NestedBlock:
		var block_count := 0
		for node in base.mouth.find_children("*", "Block", true, false):
			if Block.is_solid(node):
				block_count += 1
		if block_count > 0:
			var summary := Block.construct(BODY_SUMMARY)
			summary.data.text %= [block_count, "s" if block_count != 1 else ""]
			drag_preview.mouth.add_child(summary)

	return drag_preview_container


## Eases the preview so its centre comes to the pointer.
func animate_preview() -> void:
	var tween := base.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(base, "position", base.size / -2.0, DRAG_CENTER_DURATION)


## A right-click on a block on the canvas starts dragging a copy of it.
func handle_copying(event: InputEvent) -> void:
	if not can_copy(event):
		return
	base.get_viewport().set_input_as_handled()
	var preview := generate_preview()
	SfxPlayer.play(SfxPlayer.BLOCK_PICKED_UP)
	base.force_drag(copy(), preview)


func can_copy(event: InputEvent) -> bool:
	return (
		not Interpreter.is_running
		and event.is_action_pressed("copy")
		and base.data.draggable
		and base.data.copyable
		and not base.data.toolbox
		and base.preview_type != Block.PreviewType.DROP
	)


## A new block like this one, for the canvas.
##
## Packed into a scene and instanced rather than duplicate()d (see
## godotengine/godot#78060). Packing keeps only what the block's own scene
## owns, not the blocks put in its slots or its mouth; its slots are rebuilt
## from the copied data when it is readied.
func copy() -> Block:
	var packed := PackedScene.new()
	if packed.pack(base) != OK:
		push_error("(%s) Couldn't pack the block to copy it." % base.name)

	var block := packed.instantiate()
	block.name = "%s%d" % [base.name, block.get_instance_id()]
	block.data = base.data.deep_copy()
	block.data.toolbox = false
	for text_block in block.data.text_blocks:
		text_block.toolbox = false
	if block.data.func_type == BlockData.FuncType.ENTITY:
		block.function.object = base.function.object
	return block
