extends BlockVisualComponent
## The cap block's look while a block is dragged: its lower lip grows by half the
## dragged block's height, so there is room to drop under the last block. The
## room closes up while the drop preview itself is the last block.

@export var lower_lip: Control

var _drag_feedback_size := 0.0


func update_color(delta: float) -> void:
	super(delta)
	if _drag_feedback_size <= 0.0:
		return
	var cap := base as CapBlock
	var is_preview_last := false
	# The last visible block in the mouth.
	for i in range(cap.mouth.get_child_count() - 1, -1, -1):
		var child := cap.mouth.get_child(i)
		if child is Block and child.visible:
			is_preview_last = child.preview_type == Block.PreviewType.DROP
			break
	lower_lip.custom_minimum_size.y = 0.0 if is_preview_last else _drag_feedback_size


func start_drag_feedback(dragged: Control) -> void:
	_drag_feedback_size = dragged.size.y / 2.0


func stop_drag_feedback() -> void:
	_drag_feedback_size = 0.0
	lower_lip.custom_minimum_size.y = 0.0
