extends BlockVisualComponent

@export var lower_lip: Control

var drag_feedback_size := 0.0

func start_drag_feedback(control: Control) -> void:
	drag_feedback_size = control.size.y / 2.0

func stop_drag_feedback() -> void:
	drag_feedback_size = 0.0
	lower_lip.custom_minimum_size.y = 0.0

func _update(delta: float) -> void:
	# Call the parent visual component update for error flashing/highlighting
	super(delta)
	
	if drag_feedback_size > 0.0:
		var cap := base as CapBlock
		var is_preview_last := false
		
		# Iterate backwards to find the last visible block in the mouth
		for i in range(cap.mouth.get_child_count() - 1, -1, -1):
			var child := cap.mouth.get_child(i)
			if child is Block and child.visible:
				# If the last visible block is the drop preview, flag it
				if child.preview_type == Block.PreviewType.DROP:
					is_preview_last = true
				break
		
		lower_lip.custom_minimum_size.y = 0.0 if is_preview_last else drag_feedback_size
