class_name TutorialOverlay
extends Control

## Walks its TutorialStep children in order, one visible at a time, advancing
## on the event each step names.
##
## It lives in the Puzzle, not in the Level: the level renders inside a
## SubViewport, and anything placed there is clipped to the environment panel
## and cannot cover the toolbox or the canvas. A level opts in through
## Level.tutorial_overlay, and Puzzle.configure_level() instances it on top.

signal finished

@export var mask: TutorialMask
@export var steps: Control

var puzzle: Puzzle
var _steps: Array[TutorialStep] = []
var _index := -1


func attach(to: Puzzle) -> void:
	puzzle = to

	for child in steps.get_children():
		if child is TutorialStep:
			var step := child as TutorialStep
			step.visible = false
			_steps.append(step)
			if step.next_button != null:
				step.next_button.pressed.connect(_on_event.bind(TutorialStep.Advance.NEXT_BUTTON, &""))

	Interpreter.running_changed.connect(_on_running_changed)
	Interpreter.error_raised.connect(_on_error_raised)
	Game.level.room_completed.connect(_on_room_completed)
	Game.level.completed.connect(_on_event.bind(TutorialStep.Advance.LEVEL_COMPLETED, &""))
	Tutorial.block_placed.connect(_on_block_placed)
	Tutorial.block_trashed.connect(_on_block_trashed)
	Tutorial.message_sent.connect(_on_message_sent)
	Tutorial.assistant_replied.connect(_on_assistant_replied)

	_go_to(0)


func current_step() -> TutorialStep:
	return _steps[_index] if _index >= 0 and _index < _steps.size() else null


#region Events
func _on_running_changed() -> void:
	_on_event(TutorialStep.Advance.RUN_STARTED if Interpreter.is_running else TutorialStep.Advance.RUN_FINISHED)

func _on_error_raised(_error: Interpreter.Error) -> void:
	_on_event(TutorialStep.Advance.ERROR_RAISED)

func _on_room_completed(_index_done: int, _total: int) -> void:
	_on_event(TutorialStep.Advance.ROOM_COMPLETED)

func _on_block_placed(block: Block, _into: Block) -> void:
	_on_event(TutorialStep.Advance.BLOCK_PLACED, StringName(block.data.name))

func _on_block_trashed(block_name: StringName) -> void:
	_on_event(TutorialStep.Advance.BLOCK_TRASHED, block_name)

func _on_message_sent(_text: String) -> void:
	_on_event(TutorialStep.Advance.MESSAGE_SENT)

func _on_assistant_replied(_text: String) -> void:
	_on_event(TutorialStep.Advance.ASSISTANT_REPLIED)


func _on_event(kind: TutorialStep.Advance, block_name: StringName = &"") -> void:
	var step := current_step()
	if step == null or step.advance_on != kind:
		return
	if not step.only_block.is_empty() and String(block_name) != step.only_block:
		return
	_go_to(_index + 1)
#endregion


#region Stepping
func _go_to(index: int) -> void:
	if current_step() != null:
		current_step().visible = false
	_index = index

	var step := current_step()
	if step == null:
		_finish()
		return

	step.visible = true
	mask.visible = step.dim or step.block_input
	mask.dimmed = step.dim
	mask.block_all = step.block_input
	_update_holes()


## Every frame, because targets move: a tab opens, a panel scrolls, the window
## is resized. A target that isn't visible yet simply has no hole until it is.
func _process(_delta: float) -> void:
	_update_holes()


func _update_holes() -> void:
	var step := current_step()
	if step == null or puzzle == null:
		return
	var to_local := mask.get_global_transform().affine_inverse()
	var rects: Array[Rect2] = []
	for path in step.targets:
		var target := _resolve(path)
		if target != null and target.is_visible_in_tree():
			var r := target.get_global_rect()
			rects.append(Rect2(to_local * r.position, r.size))
	mask.set_holes(rects)


func _resolve(path: String) -> Control:
	if path.begins_with("block:"):
		var wanted := path.trim_prefix("block:")
		for node in puzzle.toolbox.find_children("*", "Block", true, false):
			if (node as Block).data.name == wanted:
				return node as Control
		return null
	return puzzle.get_node_or_null(NodePath(path)) as Control


func _finish() -> void:
	set_process(false)
	mask.visible = false
	finished.emit()
	queue_free()
#endregion
