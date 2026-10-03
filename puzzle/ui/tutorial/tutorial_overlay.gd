class_name TutorialOverlay
extends Control

## A guide (a "dimmed tutorial"): pages shown one at a time on a card over the
## whole puzzle, with the screen dimmed except for what the page points at. A
## page moves on when its button is pressed, or when the student does what it
## asks: places a block, opens the menu, presses Play. Guides.pages_for() says
## which pages a level gets; this only shows them.
##
## It lives in the Puzzle, not in the Level: the level renders inside a
## SubViewport, and anything placed there is clipped to the room panel and can't
## cover the toolbox or the canvas. A page can still point into the level ("level:"
## targets); _rect_of() works out where that is on screen.
##
## Only the dim changes: no outlines. What a page points at is simply the part of
## the screen left undimmed and clickable.

signal finished

const A := Guides.Advance
## Gap between the card and the window edge, and between the card and a target.
const CARD_MARGIN := 24.0
const FADE := 0.2

@export var mask: TutorialMask
@export var card: GuideCard

var puzzle: Puzzle
var pages: Array = []
var _index := -1
var _closing := false


func start(to: Puzzle, guide_pages: Array) -> void:
	puzzle = to
	pages = guide_pages
	if mask == null: mask = get_node_or_null(^"Mask") as TutorialMask
	if card == null: card = get_node_or_null(^"Card") as GuideCard
	if mask == null or card == null or pages.is_empty():
		push_error("Tutorial overlay is missing its Mask or Card, or has no pages; the guide can't run.")
		queue_free()
		return

	card.next_pressed.connect(_on_next)
	Interpreter.running_changed.connect(_on_running_changed)
	Interpreter.error_raised.connect(_on_error_raised)
	Game.level.room_completed.connect(_on_room_completed)
	Game.level.completed.connect(_on_level_completed)
	Tutorial.block_placed.connect(_on_block_placed)
	Tutorial.block_trashed.connect(_on_block_trashed)
	Tutorial.message_sent.connect(_on_message_sent)
	Tutorial.assistant_replied.connect(_on_assistant_replied)
	Tutorial.menu_toggled.connect(_on_menu_toggled)
	Tutorial.panel_toggled.connect(_on_panel_toggled)
	Tutorial.view_framed.connect(_on_view_framed)

	for page: Dictionary in pages:
		for path: String in page.get("targets", []):
			if not (path.begins_with("block:") or path.begins_with("level:")) and puzzle.get_node_or_null(NodePath(path)) == null:
				push_warning("Guide page '%s': target '%s' not found under Puzzle." % [page.get("title", ""), path])

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	_go_to(0)

## Ends the guide now: the pause menu's Skip.
func skip() -> void:
	_finish()

func is_running() -> bool:
	return not _closing


#region Events
# Methods rather than lambdas, so the connections go away with the overlay when
# a replayed guide replaces it.
func _on_next() -> void: _on_event(A.NEXT)
func _on_running_changed() -> void: _on_event(A.RUN_STARTED if Interpreter.is_running else A.RUN_FINISHED)
func _on_error_raised(_error: Interpreter.Error) -> void: _on_event(A.ERROR_RAISED)
func _on_room_completed(_done: int, _total: int) -> void: _on_event(A.ROOM_COMPLETED)
func _on_level_completed() -> void: _on_event(A.LEVEL_COMPLETED)
func _on_block_placed(block: Block, _into: Block) -> void: _on_event(A.BLOCK_PLACED, StringName(block.data.name))
func _on_block_trashed(block_name: StringName) -> void: _on_event(A.BLOCK_TRASHED, block_name)
func _on_message_sent(_text: String) -> void: _on_event(A.MESSAGE_SENT)
func _on_assistant_replied(_text: String) -> void: _on_event(A.ASSISTANT_REPLIED)
func _on_menu_toggled(open: bool) -> void: _on_event(A.MENU_OPENED if open else A.MENU_CLOSED)
func _on_panel_toggled(_panel: SidePanel, open: bool) -> void: _on_event(A.PANEL_OPENED if open else A.PANEL_CLOSED)
func _on_view_framed() -> void: _on_event(A.VIEW_FRAMED)

func _on_event(kind: Guides.Advance, block_name: StringName = &"") -> void:
	var page := _page()
	if page.is_empty() or _closing:
		return
	# The card's button always moves on, whatever the page waits for. A guide
	# that can wedge is worse than one somebody skipped.
	if kind == A.NEXT:
		_go_to(_index + 1)
		return
	if page.get("advance", A.NEXT) != kind:
		return
	var only: String = page.get("only", "")
	if not only.is_empty() and String(block_name) != only:
		return
	_go_to(_index + 1)
#endregion


#region Paging
func _page() -> Dictionary:
	return pages[_index] if _index >= 0 and _index < pages.size() else {}

func _go_to(index: int) -> void:
	_index = index
	var page := _page()
	if page.is_empty():
		_finish()
		return
	# A page that waits for an action shows no button, unless it names one: the
	# assistant's page offers Skip, since its reply may never come.
	var waits: bool = page.get("advance", A.NEXT) != A.NEXT and not page.has("button")
	card.show_page(page, _index, pages.size(), waits)
	mask.dimmed = page.get("dim", true)
	mask.block_all = page.get("block_input", false)
	_focus_panel(page.get("focus", ""))
	_update()

## Opens the side panel tab a page names. focus_content() rather than
## show_content(), because show_content() closes a tab that is already open.
func _focus_panel(path: String) -> void:
	if path.is_empty():
		return
	var content := puzzle.get_node_or_null(NodePath(path)) as Control
	var panel := content.get_parent() as SidePanel if content != null else null
	if panel == null:
		push_warning("Guide: focus '%s' isn't a side panel tab." % path)
		return
	panel.focus_content(content)

## Every frame, because targets move: a tab opens, a panel scrolls, the room's
## camera reframes, the window is resized.
func _process(_delta: float) -> void:
	if not _closing:
		_update()

func _update() -> void:
	var page := _page()
	if page.is_empty() or puzzle == null:
		return
	var to_local := mask.get_global_transform().affine_inverse()
	var rects: Array[Rect2] = []
	var targets: Array = page.get("targets", [])
	for path: String in targets:
		var rect := _rect_of(path)
		if rect.has_area():
			rects.append(Rect2(to_local * rect.position, rect.size))
	mask.set_holes(rects)
	# A page whose targets all went missing would dim everything and swallow the
	# one click it asks for. Drop the dim instead: the card still says what to do.
	var lost := not targets.is_empty() and rects.is_empty()
	mask.visible = (page.get("dim", true) or page.get("block_input", false)) and not lost
	_place_card(page, rects)

## Where a target is on screen, or an empty rect while it isn't showing.
##   "block:MoveBlock"   the block with that data name, in the toolbox or else on the canvas
##   "level:Visuals/X"   a node in the level, through the level's camera
##   anything else       a Control, by path from the Puzzle root
func _rect_of(path: String) -> Rect2:
	if path.begins_with("block:"):
		# The toolbox first; a worked example has an empty one, and then it's the
		# block in the program on the canvas.
		var wanted := path.trim_prefix("block:")
		for where: Node in [puzzle.toolbox, puzzle.canvas]:
			for node in where.find_children("*", "Block", true, false):
				var block := node as Block
				if block.data.name != wanted:
					continue
				# A toolbox block in a tab that isn't open: open it.
				if where == puzzle.toolbox and not block.is_visible_in_tree() and puzzle.toolbox.is_visible_in_tree():
					puzzle.toolbox.reveal(block)
				if block.is_visible_in_tree():
					return block.get_global_rect()
		return Rect2()
	if path.begins_with("level:"):
		return _level_rect(path.trim_prefix("level:"))
	var control := puzzle.get_node_or_null(NodePath(path)) as Control
	return control.get_global_rect() if control != null and control.is_visible_in_tree() else Rect2()

## A level node's rectangle as it appears on screen: world, through the level
## camera into the SubViewport, then scaled into the container showing it.
func _level_rect(node_path: String) -> Rect2:
	if not is_instance_valid(Game.level):
		return Rect2()
	var node := Game.level.get_node_or_null(NodePath(node_path))
	var viewport := puzzle.level_viewport
	var container := viewport.get_parent() as Control
	if node == null or container == null or not container.is_visible_in_tree():
		return Rect2()
	var world: Rect2 = (node as ListEntity).get_global_bounds() if node is ListEntity else LevelCamera.node_bounds(node)
	var to_viewport := viewport.get_canvas_transform()
	var scale := container.size / Vector2(viewport.size)
	var a := container.get_global_transform() * ((to_viewport * world.position) * scale)
	var b := container.get_global_transform() * ((to_viewport * world.end) * scale)
	return Rect2(a, b - a).intersection(container.get_global_rect())

## Keeps the card off what the page points at: a card takes clicks, so one
## sitting on the Play button blocks the very thing it asks for. Takes the spot
## that covers the least of the targets, preferring the middle of the screen.
func _place_card(page: Dictionary, rects: Array[Rect2]) -> void:
	var area := mask.size
	var s := card.size
	var centre := (area - s) / 2.0
	var top := Vector2(centre.x, CARD_MARGIN)
	if page.get("card", "") == "top":
		card.position = top
		return
	if rects.is_empty():
		card.position = centre
		return
	var right := area.x - s.x - CARD_MARGIN
	var bottom := area.y - s.y - CARD_MARGIN
	var spots: Array[Vector2] = [
		centre, top, Vector2(centre.x, bottom),
		Vector2(CARD_MARGIN, centre.y), Vector2(right, centre.y),
		Vector2(right, CARD_MARGIN), Vector2(right, bottom),
		Vector2(CARD_MARGIN, CARD_MARGIN), Vector2(CARD_MARGIN, bottom),
	]
	var best := spots[0]
	var best_cover := INF
	for spot in spots:
		var cover := _covered(Rect2(spot, s), rects)
		if cover < best_cover - 1.0:
			best = spot
			best_cover = cover
	# Only move when that's clearly better, so the card doesn't hop about while
	# a panel slides open under it.
	if _covered(Rect2(card.position, s), rects) > best_cover + 64.0 or card.position == Vector2.ZERO:
		card.position = best

func _covered(card_rect: Rect2, rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += card_rect.intersection(r.grow(mask.padding + CARD_MARGIN * 0.5)).get_area()
	return total

func _finish() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	finished.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)
#endregion
