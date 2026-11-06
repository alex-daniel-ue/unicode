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
## What a page points at is lit, and the card sits next to it with an arrow
## (GuidePointer) running from the card to it, rather than in a fixed spot: the
## dim alone is easy to miss on a small screen. Back goes over earlier pages
## again; a page seen before waits for nothing.

signal finished

const A := Guides.Advance
## Gap between the card and the window edge.
const CARD_MARGIN := 24.0
## Room between the card and what its arrow points at, for the arrow.
const ARROW_GAP := 90.0
## A target taking less than this share of the screen gets the arrow. A whole
## panel is plain enough lit.
const SMALL_TARGET := 0.06
## How quickly the card glides to a new spot.
const GLIDE := 10.0
## A spot has to be this much better before the card moves to it, so it doesn't
## hop about while a panel slides open under it.
const STAY_BIAS := 80.0
const FADE := 0.2

@export var mask: TutorialMask
@export var card: GuideCard
@export var pointer: GuidePointer

var puzzle: Puzzle
var pages: Array = []
var _index := -1
## The furthest page reached. Pages before it are being looked at again.
var _furthest := -1
var _closing := false
## The card's spot: whether it has one on screen yet, and which side of its
## target it's on.
var _placed := false
var _spot := ""


## Where a line from the middle of `rect` towards `toward` leaves the rect.
static func _edge_toward(rect: Rect2, toward: Vector2) -> Vector2:
	var centre := rect.get_center()
	var d := toward - centre
	if d.is_zero_approx():
		return centre
	var tx := INF if is_zero_approx(d.x) else (rect.size.x / 2.0) / absf(d.x)
	var ty := INF if is_zero_approx(d.y) else (rect.size.y / 2.0) / absf(d.y)
	return centre + d * minf(minf(tx, ty), 1.0)


## Every frame, because targets move: a tab opens, a panel scrolls, the room's
## camera reframes, the window is resized.
func _process(delta: float) -> void:
	if not _closing:
		_update(delta)


## Shows `guide_pages` over `to`, from the first page.
func start(to: Puzzle, guide_pages: Array) -> void:
	puzzle = to
	pages = guide_pages
	if mask == null:
		mask = get_node_or_null(^"Mask") as TutorialMask
	if card == null:
		card = get_node_or_null(^"Card") as GuideCard
	if pointer == null:
		pointer = get_node_or_null(^"Pointer") as GuidePointer
	if mask == null or card == null or pages.is_empty():
		push_error("Tutorial overlay is missing its Mask or Card, or has no pages; the guide can't run.")
		queue_free()
		return

	card.next_pressed.connect(_on_next)
	card.back_pressed.connect(_on_back)
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
	Tutorial.tab_shown.connect(_on_tab_shown)

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
func _on_next() -> void:
	_on_event(A.NEXT)


func _on_running_changed() -> void:
	_on_event(A.RUN_STARTED if Interpreter.is_running else A.RUN_FINISHED)


func _on_error_raised(_error: Interpreter.BlockError) -> void:
	_on_event(A.ERROR_RAISED)


func _on_room_completed(_done: int, _total: int) -> void:
	_on_event(A.ROOM_COMPLETED)


func _on_level_completed() -> void:
	_on_event(A.LEVEL_COMPLETED)


func _on_block_placed(block: Block, _into: Block) -> void:
	_on_event(A.BLOCK_PLACED, StringName(block.data.name))


func _on_block_trashed(block_name: StringName) -> void:
	_on_event(A.BLOCK_TRASHED, block_name)


func _on_message_sent(_text: String) -> void:
	_on_event(A.MESSAGE_SENT)


func _on_assistant_replied(_text: String) -> void:
	_on_event(A.ASSISTANT_REPLIED)


func _on_menu_toggled(open: bool) -> void:
	_on_event(A.MENU_OPENED if open else A.MENU_CLOSED)


func _on_panel_toggled(_panel: SidePanel, open: bool) -> void:
	_on_event(A.PANEL_OPENED if open else A.PANEL_CLOSED)


func _on_view_framed() -> void:
	_on_event(A.VIEW_FRAMED)


func _on_tab_shown(content: Control) -> void:
	_on_event(A.TAB_SHOWN, StringName(content.name))


func _on_back() -> void:
	if _index > 0 and not _closing:
		_go_to(_index - 1)


func _on_event(kind: Guides.Advance, block_name: StringName = &"") -> void:
	var page := _page()
	if page.is_empty() or _closing:
		return
	# The card's button always moves on, whatever the page waits for. A guide
	# that can wedge is worse than one somebody skipped.
	if kind == A.NEXT:
		_go_to(_index + 1)
		return
	# Looking at an earlier page again: it was done already, and only Next and
	# Back move between pages until the student is back where they were.
	if _reviewing():
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


func _reviewing() -> bool:
	return _index < _furthest


func _finish() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	pointer.shown = false
	finished.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)


func _go_to(index: int) -> void:
	_index = index
	_furthest = maxi(_furthest, index)
	var page := _page()
	if page.is_empty():
		_finish()
		return
	# A page that waits for an action shows no button, unless it names one: the
	# assistant's page offers Skip, since its reply may never come. Looked at
	# again, every page has Next.
	var waits: bool = not _reviewing() and page.get("advance", A.NEXT) != A.NEXT and not page.has("button")
	card.show_page(page, _index, pages.size(), waits, _index > 0)
	mask.dimmed = page.get("dim", true)
	mask.block_all = page.get("block_input", false)
	_spot = ""
	_focus_panel(page.get("focus", ""))
	_update(0.0)


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


func _update(delta: float) -> void:
	var page := _page()
	if page.is_empty() or puzzle == null:
		return
	var to_local := mask.get_global_transform().affine_inverse()
	var rects: Array[Rect2] = []
	var by_path := {}
	var targets: Array = page.get("targets", [])
	for path: String in targets:
		var rect := _rect_of(path)
		if rect.has_area():
			var local := Rect2(to_local * rect.position, rect.size)
			rects.append(local)
			by_path[path] = local
	mask.set_holes(rects)
	# A page whose targets all went missing would dim everything and swallow the
	# one click it asks for. Drop the dim instead: the card still says what to do.
	var lost := not targets.is_empty() and rects.is_empty()
	mask.visible = (page.get("dim", true) or page.get("block_input", false)) and not lost
	_place_card(page, rects, _arrow_targets(page, by_path), delta)


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
				if block.data.name != wanted or not block.is_visible_in_tree():
					continue
				if where == puzzle.toolbox:
					# Scrolled out of sight: bring it into view, and only light
					# the part that shows.
					puzzle.toolbox.reveal(block)
					return block.get_global_rect().intersection(puzzle.toolbox.visible_rect())
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
	var world: Rect2
	if node is ListEntity:
		world = (node as ListEntity).get_global_bounds()
	elif node is Control:
		world = (node as Control).get_global_rect()  # a room's label
	else:
		world = LevelCamera.node_bounds(node)
	var to_viewport := viewport.get_canvas_transform()
	var scale := container.size / Vector2(viewport.size)
	var a := container.get_global_transform() * ((to_viewport * world.position) * scale)
	var b := container.get_global_transform() * ((to_viewport * world.end) * scale)
	return Rect2(a, b - a).intersection(container.get_global_rect())
#endregion


#region Card and arrow
## What the arrows point at: the page's "arrow" target, or each of its list of
## them ("" or [] for none), else its smallest target, when that is small
## enough to need pointing out. The card sits by the first.
func _arrow_targets(page: Dictionary, by_path: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if page.has("arrow"):
		var named: Array = page.arrow if page.arrow is Array else [page.arrow]
		for path: String in named:
			var rect: Rect2 = by_path.get(path, Rect2())
			if rect.has_area():
				out.append(rect)
		return out
	var screen := mask.size.x * mask.size.y
	var best := Rect2()
	for path: String in by_path:
		var rect: Rect2 = by_path[path]
		if rect.get_area() < screen * SMALL_TARGET and (not best.has_area() or rect.get_area() < best.get_area()):
			best = rect
	if best.has_area():
		out.append(best)
	return out


func _place_card(page: Dictionary, rects: Array[Rect2], arrows_to: Array[Rect2], delta: float) -> void:
	var area := mask.size
	var s := card.size
	var goal := (area - s) / 2.0
	var on_top: bool = page.get("card", "") == "top"
	var first: Rect2 = arrows_to[0] if not arrows_to.is_empty() else Rect2()
	if on_top:
		goal = Vector2(goal.x, CARD_MARGIN)
	elif first.has_area():
		goal = _spot_near(first, rects)
	elif not rects.is_empty():
		goal = _spot_clear_of(rects)

	if not _placed or delta <= 0.0 and card.position == Vector2.ZERO:
		card.position = goal
		_placed = true
	else:
		card.position = card.position.lerp(goal, minf(1.0, delta * GLIDE))

	var card_rect := Rect2(card.position, s)
	var pairs: Array[PackedVector2Array] = []
	if not on_top:
		for target in arrows_to:
			if card_rect.grow(12.0).intersects(target):
				continue
			pairs.append(PackedVector2Array([
				_edge_toward(card_rect, target.get_center()),
				_edge_toward(target.grow(mask.padding + 4.0), card_rect.get_center()),
			]))
	pointer.arrows = pairs
	pointer.shown = not pairs.is_empty()


## The spot beside `target` that leaves the page's targets clearest, a gap away
## so the arrow has room. Tries each side of the target itself, then each side
## of everything lit together (a button beside a panel), and keeps the spot it
## is in unless another is clearly better.
func _spot_near(target: Rect2, rects: Array[Rect2]) -> Vector2:
	var s := card.size
	var all_lit := target
	for rect in rects:
		all_lit = all_lit.merge(rect)
	var spots := {}
	for pair in [["", target], ["all ", all_lit]]:
		var around: Rect2 = pair[1]
		var key: String = pair[0]
		spots[key + "right"] = Vector2(around.end.x + ARROW_GAP, target.get_center().y - s.y / 2.0)
		spots[key + "left"] = Vector2(around.position.x - ARROW_GAP - s.x, target.get_center().y - s.y / 2.0)
		spots[key + "below"] = Vector2(target.get_center().x - s.x / 2.0, around.end.y + ARROW_GAP)
		spots[key + "above"] = Vector2(target.get_center().x - s.x / 2.0, around.position.y - ARROW_GAP - s.y)
	# The corners and edges too: on a small screen a tall card beside its
	# target can only go over the panel the target is in.
	var area := mask.size
	for x in [0.0, 0.5, 1.0]:
		for y in [0.0, 0.5, 1.0]:
			if x != 0.5 or y != 0.5:
				spots["screen %s %s" % [x, y]] = Vector2((area.x - s.x) * x, (area.y - s.y) * y)
	var best_key := ""
	var best_score := INF
	var scores := {}
	for key: String in spots:
		spots[key] = _on_screen(spots[key])
		scores[key] = _score(Rect2(spots[key], s), target, rects)
		if scores[key] < best_score:
			best_score = scores[key]
			best_key = key
	if spots.has(_spot) and scores[_spot] <= best_score + STAY_BIAS:
		best_key = _spot
	_spot = best_key
	return spots[best_key]


## How bad a card at `card_rect` is: far from its target is a little bad;
## covering a small target (a button, a block) is very bad; covering a big one
## (a panel) only somewhat; too close to its target for an arrow, bad.
func _score(card_rect: Rect2, target: Rect2, rects: Array[Rect2]) -> float:
	var screen := mask.size.x * mask.size.y
	var score := card_rect.get_center().distance_to(target.get_center())
	for rect in rects:
		var cover := card_rect.intersection(rect.grow(mask.padding + 8.0)).get_area()
		if cover <= 0.0:
			continue
		var small := rect.get_area() < screen * SMALL_TARGET
		score += cover / maxf(rect.get_area(), 1.0) * (100000.0 if small else 3000.0)
	if card_rect.intersects(target.grow(ARROW_GAP * 0.5)):
		score += 20000.0
	return score


## No small target to point at: the spot that covers the least of the lit
## parts, preferring the middle of the screen.
func _spot_clear_of(rects: Array[Rect2]) -> Vector2:
	var area := mask.size
	var s := card.size
	var centre := (area - s) / 2.0
	var right := area.x - s.x - CARD_MARGIN
	var bottom := area.y - s.y - CARD_MARGIN
	var spots := {
		"centre": centre, "top": Vector2(centre.x, CARD_MARGIN), "bottom": Vector2(centre.x, bottom),
		"left": Vector2(CARD_MARGIN, centre.y), "right": Vector2(right, centre.y),
		"top right": Vector2(right, CARD_MARGIN), "bottom right": Vector2(right, bottom),
		"top left": Vector2(CARD_MARGIN, CARD_MARGIN), "bottom left": Vector2(CARD_MARGIN, bottom),
	}
	var best_key := "centre"
	var best_cover := INF
	var covers := {}
	for key: String in spots:
		covers[key] = _covered(Rect2(spots[key], s), rects)
		if covers[key] < best_cover - 1.0:
			best_cover = covers[key]
			best_key = key
	if spots.has(_spot) and covers[_spot] <= best_cover + 64.0 * 64.0:
		best_key = _spot
	_spot = best_key
	return spots[best_key]


func _covered(card_rect: Rect2, rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += card_rect.intersection(r.grow(mask.padding + CARD_MARGIN * 0.5)).get_area()
	return total


func _on_screen(spot: Vector2) -> Vector2:
	var area := mask.size
	var s := card.size
	return Vector2(
		clampf(spot.x, CARD_MARGIN, maxf(CARD_MARGIN, area.x - s.x - CARD_MARGIN)),
		clampf(spot.y, CARD_MARGIN, maxf(CARD_MARGIN, area.y - s.y - CARD_MARGIN)))
#endregion
