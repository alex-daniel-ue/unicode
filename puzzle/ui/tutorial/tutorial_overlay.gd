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

const LEFT := "UserInterface/SideMenuLeft/Panel"
const LEFT_BUTTONS := "UserInterface/SideMenuLeft/ButtonContainer/"
const RIGHT_BUTTONS := "UserInterface/SideMenuRight/ButtonContainer/"
const WORKSPACE := "UserInterface/MiddleSpace"
const A := TutorialStep.Advance

## The tour's behaviour, keyed by step node name. This table wins over whatever
## the step nodes carry in tutorial_overlay.tscn: those exported values have
## been lost from the scene file twice (a save while the step script wasn't
## loaded writes the scene without them), and every loss dimmed the whole
## screen and swallowed the one click the step asked for. The scene now only
## has to supply the cards' words. Edit here, not in the inspector.
const PLAN := {
	&"Welcome": {},
	&"TheRoom": {targets = ["UserInterface/SideMenuRight/Panel"]},
	&"Instructions": {focus = LEFT + "/PuzzleInformation", targets = [LEFT]},
	&"TheToolbox": {focus = LEFT + "/PuzzleToolbox", targets = [LEFT, LEFT_BUTTONS + "ToolboxMenuButton"]},
	&"DragABlock": {advance = A.BLOCK_PLACED, only = "MoveBlock", focus = LEFT + "/PuzzleToolbox", targets = [LEFT, WORKSPACE]},
	&"Trash": {advance = A.BLOCK_TRASHED, targets = [LEFT_BUTTONS + "TrashButton", WORKSPACE]},
	&"PlaceAgain": {advance = A.BLOCK_PLACED, only = "MoveBlock", focus = LEFT + "/PuzzleToolbox", targets = [LEFT, WORKSPACE]},
	&"Assistant": {advance = A.MESSAGE_SENT, focus = LEFT + "/AIAssistant", targets = [LEFT, LEFT_BUTTONS + "AIAssistantMenuButton"]},
	&"Watcher": {focus = LEFT + "/VariableWatcher", targets = [LEFT, LEFT_BUTTONS + "VariableWatcherMenuButton"]},
	&"PressPlay": {advance = A.RUN_STARTED, targets = [RIGHT_BUTTONS + "PlayButton", RIGHT_BUTTONS + "SpeedButton", RIGHT_BUTTONS + "StopButton"]},
	&"Watch": {advance = A.RUN_FINISHED, dim = false, block_input = true},
}

@export var mask: TutorialMask
@export var steps: Control
## A plain Control above the mask that draws an outline around each target. It
## carries no material, so it draws the same on every renderer: if the mask's
## holes ever fail to cut, the targets are still ringed.
@export var rings: Control
@export var ring_color := Color(1.0, 0.82, 0.3, 1.0)
@export var ring_width := 3

var puzzle: Puzzle
var _steps: Array[TutorialStep] = []
var _index := -1
var _ring_rects: Array[Rect2] = []
var _ring_box := StyleBoxFlat.new()
## Where each step's card was authored, in overlay space, keyed by step.
var _card_home := {}

## Gap between a moved card and the window edge.
const CARD_MARGIN := 24.0


func attach(to: Puzzle) -> void:
	puzzle = to
	# Same failure as the step values: these node references live in the scene
	# file and go missing with it. The children are always there by name.
	if mask == null: mask = get_node_or_null(^"Mask") as TutorialMask
	if steps == null: steps = get_node_or_null(^"Steps") as Control
	if rings == null: rings = get_node_or_null(^"Rings") as Control
	if mask == null or steps == null:
		push_error("Tutorial overlay is missing its Mask or Steps node; the tour can't run.")
		queue_free()
		return

	_ring_box.draw_center = false
	_ring_box.border_color = ring_color
	_ring_box.set_border_width_all(ring_width)
	_ring_box.set_corner_radius_all(8)
	if rings != null:
		rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rings.draw.connect(_draw_rings)

	for child in steps.get_children():
		if child is TutorialStep:
			var step := child as TutorialStep
			step.visible = false
			_apply_plan(step)
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


## Overwrites the step's exported behaviour with its PLAN entry, and finds its
## Next button by name if the scene lost that reference too. Reports anything
## that won't resolve, so a broken tour says so in the Output panel.
func _apply_plan(step: TutorialStep) -> void:
	if step.next_button == null:
		step.next_button = step.find_child("NextButton", true, false) as BaseButton
	if not PLAN.has(step.name):
		push_warning("Tutorial: step '%s' has no PLAN entry; using its scene values." % step.name)
		return
	var plan: Dictionary = PLAN[step.name]
	step.advance_on = plan.get("advance", A.NEXT_BUTTON)
	step.only_block = plan.get("only", "")
	step.focus_panel = plan.get("focus", "")
	step.targets = PackedStringArray(plan.get("targets", []))
	step.dim = plan.get("dim", true)
	step.block_input = plan.get("block_input", false)
	for path in step.targets:
		if _resolve(path) == null:
			push_warning("Tutorial step '%s': target '%s' not found under Puzzle." % [step.name, path])
	if step.advance_on == A.NEXT_BUTTON and step.next_button == null:
		push_warning("Tutorial step '%s' waits for a Next button it doesn't have." % step.name)


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
	if step == null:
		return
	# A Next button always advances, whatever the step is waiting for. A tour that
	# can wedge is worse than one somebody skipped, and the assistant step would
	# otherwise sit on a network round trip lab day may not deliver.
	if kind == TutorialStep.Advance.NEXT_BUTTON and step.next_button != null:
		_go_to(_index + 1)
		return
	if step.advance_on != kind:
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
	mask.dimmed = step.dim
	mask.block_all = step.block_input
	_focus_panel(step)
	_update_holes()


## Opens the side panel tab the step names. focus_content() rather than
## show_content(), because show_content() closes a tab that is already open.
func _focus_panel(step: TutorialStep) -> void:
	if step.focus_panel.is_empty():
		return
	var content := puzzle.get_node_or_null(NodePath(step.focus_panel)) as Control
	var panel: SidePanel = null
	if content != null:
		panel = content.get_parent() as SidePanel
	if panel == null:
		push_warning("Tutorial step '%s': focus_panel '%s' isn't a side panel tab." % [step.name, step.focus_panel])
		return
	panel.focus_content(content)


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

	# A step that names targets but resolves none would dim the whole screen and
	# swallow every click, so one stale node path wedges the tour on exactly the
	# steps that ask the student to do something. Drop the mask instead: no
	# highlight, but the UI stays usable and the card still says what to do.
	var lost := not step.targets.is_empty() and rects.is_empty()
	mask.visible = (step.dim or step.block_input) and not lost

	var ringed: Array[Rect2] = []
	if step.dim and not step.block_input:
		for r in rects:
			ringed.append(r.grow(mask.padding + ring_width))
	_place_card(step, rects)
	if ringed != _ring_rects:
		_ring_rects = ringed
		if rings != null:
			rings.queue_redraw()


## Keeps the step's card off what it points at. A card is a Control that takes
## clicks, so one sitting on the Play button or on the begin block's mouth blocks
## the very action it asks for, and on a 1152-wide window the centred cards did
## exactly that. Tries the authored spot first, then the corners and edges, and
## takes the one that covers the least of the targets. Moves only when that is
## clearly better, so the card doesn't hop while a panel animates open.
func _place_card(step: TutorialStep, rects: Array[Rect2]) -> void:
	var card := step.get_node_or_null(^"Card") as Control
	if card == null or rects.is_empty() or not card.size.x > 0.0:
		return
	if not _card_home.has(step):
		# Record where the authored anchors put it, then pin it top-left so
		# `position` means the same thing for every candidate spot below.
		var authored := card.position
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = authored
		_card_home[step] = authored
	var home: Vector2 = _card_home[step]
	var area := mask.size
	var s := card.size
	var right := area.x - s.x - CARD_MARGIN
	var bottom := area.y - s.y - CARD_MARGIN
	var centre_x := (area.x - s.x) / 2.0
	var spots: Array[Vector2] = [
		home,
		Vector2(centre_x, CARD_MARGIN), Vector2(centre_x, bottom),
		Vector2(right, CARD_MARGIN), Vector2(right, bottom),
		Vector2(CARD_MARGIN, CARD_MARGIN), Vector2(CARD_MARGIN, bottom),
		Vector2(centre_x, (area.y - s.y) / 2.0),
	]
	var best := home
	var best_cover := INF
	for spot in spots:
		var cover := _covered(Rect2(spot, s), rects)
		if cover < best_cover:
			best = spot
			best_cover = cover
	if _covered(Rect2(card.position, s), rects) > best_cover + 64.0:
		card.position = best


func _covered(card_rect: Rect2, rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += card_rect.intersection(r.grow(mask.padding + ring_width)).get_area()
	return total


func _draw_rings() -> void:
	# Rings share the mask's local space: both are full-rect children of the overlay.
	for r in _ring_rects:
		rings.draw_style_box(_ring_box, r)


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
	_ring_rects.clear()
	if rings != null:
		rings.queue_redraw()
	finished.emit()
	queue_free()
#endregion
