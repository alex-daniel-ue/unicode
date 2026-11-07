class_name CapBlock
extends NestedBlock
## A nested block with nothing above it: Begin, where the program starts.
## While a block is dragged, its lower lip makes room under the program, so the
## end of the program is somewhere to drop.

## The begin block flashes when Play is pressed: a quick bright pop, so the eye
## goes to where the program starts before the robot moves.
const FLASH := Color(1.9, 1.9, 1.9)
const FLASH_SCALE := 1.08
const FLASH_TIME := 0.14

var _flash_tween: Tween


func _ready() -> void:
	super()
	Interpreter.running_changed.connect(_on_running_changed)


## Begin is drawn as its hat alone: the blocks under it are their own, and the
## rest of its box is canvas.
func shows_at(point: Vector2) -> bool:
	return upper_lip.get_global_rect().has_point(point)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			if get_viewport().gui_get_drag_data() is Block and is_instance_valid(PuzzleCanvas.drag_preview):
				visual.start_drag_feedback(PuzzleCanvas.drag_preview)
		NOTIFICATION_DRAG_END:
			visual.stop_drag_feedback()


## Twice bright, with a small pop. Only the begin block's own colour flashes;
## the blocks inside it keep theirs.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	pivot_offset = Vector2(upper_lip.size.x / 2.0, upper_lip.size.y / 2.0)
	_flash_tween = create_tween()
	for i in 2:
		_flash_tween.tween_callback(func() -> void: visual.target_color = FLASH)
		_flash_tween.tween_property(self, "scale", Vector2.ONE * FLASH_SCALE, FLASH_TIME * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flash_tween.tween_callback(visual.reset)
		_flash_tween.tween_property(self, "scale", Vector2.ONE, FLASH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_running_changed() -> void:
	if Interpreter.is_running and is_type(NestedData.Type.BEGIN) and is_visible_in_tree() \
			and preview_type == Block.PreviewType.NONE and not data.toolbox:
		flash()
