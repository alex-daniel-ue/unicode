extends Node

## Walks the first level's tour by doing what each page asks, through the real
## buttons where there is one, and reports any page it can't get past. The trash
## page is passed with Trash all, the way that used to strand the tour.
##   godot --headless --path . res://tools/tour_check.tscn

const A := Guides.Advance
const RIGHT := "UserInterface/SideMenuRight/ButtonContainer/"


func _ready() -> void:
	var level: Level = (load("res://level/levels/tutorial_1.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"tour_check"
	Interpreter.is_fast = true
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	add_child(puzzle)
	puzzle.configure_level()
	for i in 5: await get_tree().process_frame

	var guides := puzzle.find_children("*", "TutorialOverlay", true, false)
	if guides.is_empty():
		_done("FAIL: tutorial_1 opened without its tour.")
		return
	var guide := guides[0] as TutorialOverlay
	var hidden: PackedStringArray = []
	for path: String in Puzzle.EXTRA_UI:
		if (puzzle.get_node(path) as Control).visible:
			hidden.append(path.get_file())
	if not hidden.is_empty():
		_done("FAIL: minimal UI still shows %s." % ", ".join(hidden))
		return

	var stuck := 0
	while guide.is_running():
		var index := guide._index
		var page: Dictionary = guide._page()
		await _do(puzzle, page)
		for i in 30: await get_tree().process_frame
		while Interpreter.is_running:
			await get_tree().process_frame
		for i in 5: await get_tree().process_frame
		if guide.is_running() and guide._index == index:
			stuck += 1
			if stuck > 1:
				_done("FAIL: stuck on page %d, '%s'." % [index + 1, page.get("title", "")])
				return
		else:
			stuck = 0

	# The pause menu's button shows it again, and pressed again, skips it.
	puzzle._on_tutorials_requested()
	await get_tree().process_frame
	var again := puzzle.find_children("*", "TutorialOverlay", true, false).filter(
		func(node: Node) -> bool: return (node as TutorialOverlay).is_running())
	if again.is_empty() or (again[0] as TutorialOverlay)._index != 0:
		_done("FAIL: the menu's tutorial button didn't show the tour again from its start.")
		return
	puzzle._on_tutorials_requested()
	if (again[0] as TutorialOverlay).is_running():
		_done("FAIL: the menu's tutorial button didn't skip the tour on screen.")
		return
	_done("PASS: every page of the tour was passed by doing what it asked, and the menu replays and skips it.")

func _do(puzzle: Puzzle, page: Dictionary) -> void:
	var begin := puzzle._get_begin()
	match page.get("advance", A.NEXT):
		A.NEXT:
			(puzzle.find_children("*", "GuideCard", true, false)[0] as GuideCard).next_button.pressed.emit()
		A.VIEW_FRAMED:
			(puzzle.get_node(RIGHT + "FrameButton") as Button).pressed.emit()
		A.PANEL_CLOSED, A.PANEL_OPENED:
			(puzzle.get_node(RIGHT + "EnvironmentButton") as Button).pressed.emit()
		A.BLOCK_PLACED:
			# A drag can't be scripted; place the block the way a drop does and
			# say so the way drop_manager does.
			var block := Block.construct(load("res://level/objects/entities/robot/blocks/move.tres"))
			begin.mouth.add_child(block)
			await get_tree().process_frame
			Tutorial.block_placed.emit(block, begin)
		A.BLOCK_TRASHED:
			# Trash all, not a drag onto the bin: the case that used to strand it.
			puzzle.canvas.clear()
		A.MENU_OPENED:
			puzzle.open_menu()
		A.MENU_CLOSED:
			puzzle.pause_menu.hide()
		A.RUN_STARTED:
			(puzzle.get_node(RIGHT + "PlayButton") as Button).pressed.emit()
		A.RUN_FINISHED:
			pass  # the run started on the page before finishes by itself

func _done(result: String) -> void:
	print("TOUR ", result)
	get_tree().quit()
