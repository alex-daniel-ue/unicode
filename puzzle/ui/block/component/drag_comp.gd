class_name BlockDragComponent
extends BlockBaseComponent


const DRAG_CENTER_DURATION := 0.5
const DRAG_PREVIEW_TRANSPARENCY := 0.5

var dummy_data := load("res://puzzle/ui/block/dummy.tres")


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
		for node in Core.get_children_recursive(base.mouth, true):
			if node is Block and Block.IS_SOLID.call(node):
				block_count += 1
		
		if block_count > 0:
			var dummy := Block.construct(dummy_data.duplicate(true))
			dummy.data.text %= [block_count, "s" if block_count != 1 else ""]
			
			drag_preview.mouth.add_child(dummy)
	
	return drag_preview_container

func animate_preview() -> void:
	var tween := base.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(base, "position", base.size / -2., DRAG_CENTER_DURATION)

func handle_copying(event: InputEvent) -> void:
	if is_copy_valid(event):
		base.get_viewport().set_input_as_handled()
		
		var preview := generate_preview()
		Core.current_drag_preview = preview
		
		base.force_drag(copy(), preview)

func is_copy_valid(event: InputEvent) -> bool:
	return bool(
		not Puzzle.is_running and
		event.is_action_pressed("copy") and
		base.data.draggable and
		not base.data.toolbox and
		not base.preview_type == Block.PreviewType.DROP
	)

func copy() -> Block:
	_set_block_owner(self)
	
	# Workaround for node duplication based on GitHub issue #78060
	# WARNING: This packing/instantiating method may have unforeseen
	# consequences, particularly regarding node ownership
	var packed_scn := PackedScene.new()
	if packed_scn.pack(base) != OK:
		Debug.log("Copy failed! (packed scene workaround)")
	
	var block := packed_scn.instantiate()
	
	block.name = "%s%d" % [base.name, block.get_instance_id()]
	block.data = base.data.duplicate(true)
	
	block.data.toolbox = false
	for text_block in block.data.text_blocks:
		text_block.toolbox = false
	
	if block.data.func_type == BlockData.FuncType.ENTITY:
		block.function.object = base.function.object
	
	return block

# MEDIUM FIXME: Verify if explicitly setting the node owner recursively is still
# necessary.
func _set_block_owner(node: Node) -> void:
	return
	
	#for child in Core.get_children_recursive(node, true):
		#if child.owner == null:
			#child.owner = node
			#if child is Block:
				#_set_block_owner(child)
