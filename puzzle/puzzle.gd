class_name Puzzle
extends Control
## The puzzle screen for one level: the level in the room panel, the canvas, the
## side panels, the guide, the pause menu and the win card.
##
## Level select sets Game.level_scene and Game.level_id, and this instantiates
## the level and wires everything for it (configure_level()). Play calls
## run_program(), which runs the program under Begin in every room.

## Runs that fail before the assistant offers to look at the last one.
const NUDGE_AFTER := [1, 4, 7]
const TUTORIAL_OVERLAY := preload("res://puzzle/ui/tutorial/tutorial_overlay.tscn")
## The Information tab: the level's description. What the left panel shows when
## a level opens, after a guide that pointed into the Toolbox, and when a run has
## no variables to show.
const INFORMATION_TAB := "UserInterface/SideMenuLeft/Panel/PuzzleInformation"
const ROOM_TAB := "UserInterface/SideMenuRight/Panel/PuzzleEnvironment"
const VALUE_TAGS := "ValueTags"
## How long the value tags from a solved room stay once the next room starts.
const ROOM_TAGS_FADE_AFTER := 0.6
## Hidden when a level asks for the minimal UI (Level.minimal_ui): the first
## levels show only what they use, because everything at once lost people.
const EXTRA_UI := [
	"UserInterface/SideMenuLeft/ButtonContainer/AIAssistantMenuButton",
	"UserInterface/SideMenuLeft/ButtonContainer/VariableWatcherMenuButton",
	"UserInterface/SideMenuRight/ButtonContainer/SpeedButton",
]

@export_group("Children")
@export var canvas: PuzzleCanvas
@export var side_panels: Array[SidePanel]
@export var information: Container
@export var toolbox: Toolbox
@export var ai_assistant: AIAssistant
@export var notifications: NotificationStack
@export var level_viewport: SubViewport
@export var level_complete: LevelComplete
@export var pause_menu: PauseMenu

## The program as it was at the last Play, for the assistant and the win card.
var last_run_yaml := ""

var _failed_runs := 0
var _last_run_result := "The student hasn't pressed Play on this level yet."
var _placed_blocks := 0
var _paused_before_menu := false
## The guide on screen, if any, and the pages this level's guide has.
var _guide: TutorialOverlay
var _guide_pages: Array = []
## The Information tab's way on to the Toolbox, off while a program runs.
var _go_to_toolbox: Button


func _ready() -> void:
	side_panels[0].focus_content(get_node(INFORMATION_TAB) as Control)
	# focus_content, not show_menu: the panel has to know the room is what it
	# shows, or the room button's first press only "switches" to it.
	side_panels[1].focus_content(get_node(ROOM_TAB) as Control)

	if Game.level_scene != null:
		Game.level = Game.level_scene.instantiate() as Level
		configure_level()

	Interpreter.error_raised.connect(_on_interpreter_error)
	Interpreter.output_logged.connect(_on_interpreter_output)
	Interpreter.running_changed.connect(_on_interpreter_running_changed)
	pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed)
	pause_menu.tutorials_requested.connect(_on_tutorials_requested)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		open_menu()
	elif event.is_action_released("pause"):
		pause_menu.hide()


func _exit_tree() -> void:
	Interpreter.is_running = false
	Interpreter.clear_state()


## Puts Game.level in the room panel and sets the screen up for it.
func configure_level() -> void:
	Interpreter.clear_scopes()

	Game.level.completed.connect(_on_level_completed)
	Game.level.failed.connect(_on_level_failed)
	Game.level.room_completed.connect(_on_room_completed)

	for node in level_viewport.get_children():
		node.queue_free()
	level_viewport.add_child(Game.level)

	for child in information.get_children():
		child.queue_free()
	for content in Game.level.description.take_content():
		# The brief is built fresh and has no parent yet; authored children do.
		if content.get_parent() == null:
			information.add_child(content)
		else:
			content.reparent(information)
	_go_to_toolbox = _make_toolbox_button()
	information.add_child(_go_to_toolbox)

	for block in Game.level.get_blocks():
		toolbox.add_block(block)
	var description := Game.level.description
	toolbox.mark_new(description.blocks, description.block_notes)

	for path: String in EXTRA_UI:
		(get_node(path) as Control).visible = not Game.level.minimal_ui

	# level.tscn ships a Begin block, so get_preset() is only null on a level
	# whose LevelBlockPreset was emptied, which would otherwise read at runtime
	# as "Play does nothing" rather than as the authoring mistake it is.
	var preset := Game.level.preset.get_preset()
	if preset == null:
		push_error("Level '%s': LevelBlockPreset has no Block child. It needs the begin block." % Game.level.name)
		notifications.push("This level has no begin block, so it can't be played.", Notification.Type.ERROR)
	else:
		preset.reparent(canvas)
		preset.position = canvas.size / 2.0
		preset.visible = true
		_place_defines(preset.position)

	SfxPlayer.play(SfxPlayer.LEVEL_START)
	# The assistant keeps a picture of the level as it starts, to send beside the
	# one taken when a question is asked (which, after a run, shows its result).
	ai_assistant.capture_start()

	# The guide comes first, and a worked example only runs itself once the
	# student has been through it.
	_guide_pages = Guides.pages_for(Game.level)
	start_guide()
	if Game.level.auto_run:
		if is_instance_valid(_guide):
			_guide.finished.connect(_auto_run, CONNECT_ONE_SHOT)
		else:
			_auto_run()


## Runs the program under Begin in every room. Play calls this.
func run_program() -> void:
	for err in Interpreter.active_errors:
		if is_instance_valid(err.block):
			err.block.visual.set_error(false)

	if Interpreter.is_running:
		notifications.push("The program is already running.", Notification.Type.ERROR)
		return
	Interpreter.clear_state()

	var begin := _find_begin()
	if begin == null:
		notifications.push("There is no begin block on the canvas.", Notification.Type.ERROR)
		return
	if begin.get_blocks().is_empty():
		notifications.push("The begin block has no blocks under it. Attach a block to it first.", Notification.Type.ERROR)
		return

	last_run_yaml = canvas.serializer.yaml_serialize()
	_placed_blocks = Serializer.count_solid_blocks(last_run_yaml)

	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true

	var cleared := await Game.level.run_rooms(begin)
	if not cleared:
		_report_failure()
		_failed_runs += 1
		if _failed_runs in NUDGE_AFTER and not Game.level.minimal_ui:
			notifications.push(
				"Stuck? The assistant can look at your last run.",
				Notification.Type.LOG,
				func() -> void:
					side_panels[0].focus_content(ai_assistant)
					ai_assistant.prompt_for_question()
			)
		_last_run_result = "Did not solve the level; the reason is in the output log."
	else:
		_failed_runs = 0
		_last_run_result = "Solved every room."

	Interpreter.is_running = false
	side_panels[1].keep_state = false
	Game.level.camera.frame()


## How the last run went, and whether the blocks have changed since, for the
## assistant.
func describe_last_run() -> String:
	if last_run_yaml.is_empty():
		return _last_run_result
	var changed := last_run_yaml != canvas.serializer.yaml_serialize()
	return _last_run_result + (" The blocks have changed since that run." if changed else " The blocks are unchanged since that run.")


## Esc and the on-screen menu button both land here. A run pauses behind the menu
## and gets its previous state back when the menu closes.
func open_menu() -> void:
	if pause_menu.visible:
		return
	_paused_before_menu = Interpreter.is_paused
	Interpreter.is_paused = true
	pause_menu.set_tutorial_state(not _guide_pages.is_empty(), is_instance_valid(_guide) and _guide.is_running())
	pause_menu.show()


func start_guide() -> void:
	if _guide_pages.is_empty():
		return
	if is_instance_valid(_guide):
		_guide.skip()
	_guide = TUTORIAL_OVERLAY.instantiate() as TutorialOverlay
	add_child(_guide)
	_guide.finished.connect(_on_guide_finished)
	_guide.start(self, _guide_pages)


func show_information() -> void:
	side_panels[0].focus_content(get_node(INFORMATION_TAB) as Control)


## Whether `block`, let go at `at` (global), goes back into the open toolbox:
## a block from the canvas, over the left panel while it shows the toolbox.
## Putting a block back where blocks come from throws it away, as the trash
## can does (trash_button.gd); a fresh copy from the toolbox isn't on the
## canvas yet, so letting it go there just cancels the drag.
func returns_to_toolbox(block: Block, at: Vector2) -> bool:
	var panel := side_panels[0]
	return (
		is_instance_valid(block) and block.is_inside_tree() and not block.data.toolbox
		and panel.is_open and panel.shown_content == toolbox
		and panel.get_global_rect().has_point(at)
	)


## The level's functions, a define block each, to the left of Begin and one
## under another.
func _place_defines(begin_at: Vector2) -> void:
	var at := begin_at + FunctionDefinitions.OFFSET
	for node in Game.level.find_children("*", "FunctionDefinitions", true, false):
		for define in (node as FunctionDefinitions).define_blocks():
			canvas.add_child(define)
			define.position = at
			define.visible = true
			at.y += maxf(define.get_combined_minimum_size().y, 80.0) + FunctionDefinitions.GAP


## The way on from the Information tab once it has been read: to the blocks.
## The same as the toolbox's own tab button, so a guide waiting for that tab
## moves on too, and off while a program runs, as that button is. Quiet, like
## the tab buttons.
func _make_toolbox_button() -> Button:
	var button := Button.new()
	button.name = "GoToToolbox"
	button.text = "Go to Toolbox"
	button.theme_type_variation = &"MainMenuButton"
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_go_to_toolbox_pressed)
	return button


## Worked examples play themselves once, after a moment to take in the canvas.
## A child Timer rather than a SceneTreeTimer, so leaving the level early frees it
## instead of resuming into a freed Puzzle. Waits out the pause menu rather than
## starting behind it, and does nothing if the student already pressed Play.
func _auto_run() -> void:
	notifications.push("Watch: this program runs by itself in a moment.", Notification.Type.LOG)
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_auto_run_timeout.bind(timer))
	add_child(timer)
	timer.start(Game.level.auto_run_delay)


func _find_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null


func _show_level_complete(stars: int) -> void:
	var card := level_complete.present(
		stars, _placed_blocks, Game.level.get_star_par(), Game.level.star_slack, true
	)
	# The card is up before this returns; the summary fills in when it arrives.
	# last_run_yaml is the program as it was when Play was pressed: the winner.
	var summary := await ai_assistant.request_summary(
		last_run_yaml, _placed_blocks, Game.level.get_star_par()
	)
	if is_instance_valid(level_complete):
		level_complete.show_summary(summary, card)


## The output log's last word when a run failed with no error and no failed goal.
func _report_failure() -> void:
	if not Interpreter.active_errors.is_empty() or Game.level.has_failed:
		return
	const MESSAGE := "The program didn't finish."
	Interpreter.output_log.append(MESSAGE)
	notifications.push(MESSAGE, Notification.Type.ERROR)


func _on_go_to_toolbox_pressed() -> void:
	side_panels[0].focus_content(toolbox)
	Tutorial.tab_shown.emit(toolbox)


func _on_auto_run_timeout(timer: Timer) -> void:
	if pause_menu.visible or (is_instance_valid(_guide) and _guide.is_running()):
		timer.start(0.5)
		return
	timer.queue_free()
	if Interpreter.is_running or level_complete.visible:
		return
	run_program()


func _on_pause_menu_visibility_changed() -> void:
	if not pause_menu.visible:
		Interpreter.is_paused = _paused_before_menu
	Tutorial.menu_toggled.emit(pause_menu.visible)


## The pause menu's tutorial button: skips the guide that's showing, or shows
## this level's guide again from its first page.
func _on_tutorials_requested() -> void:
	if is_instance_valid(_guide) and _guide.is_running():
		_guide.skip()
	else:
		start_guide()


## A guide about new blocks leaves the toolbox open. The task is what to read
## next, so the panel goes back to it.
func _on_guide_finished() -> void:
	if side_panels[0].shown_content == toolbox:
		show_information()


func _on_level_completed() -> void:
	Interpreter.interrupted = true
	SfxPlayer.play(SfxPlayer.SUCCESS)
	var stars := Game.level.calculate_stars(_placed_blocks)
	Progress.record_completion(Game.level_id, stars)
	_show_level_complete(stars)


func _on_level_failed(reason: String) -> void:
	Interpreter.interrupted = true
	notifications.push(reason, Notification.Type.ERROR)


func _on_room_completed(index: int, total: int) -> void:
	if total <= 1:
		return
	# The last room's sound is the level's own.
	if index + 1 < total:
		SfxPlayer.play(SfxPlayer.NEXT_ROOM)
		(get_node(VALUE_TAGS) as ValueTags).fade_stale(ROOM_TAGS_FADE_AFTER)
	notifications.push("You solved Room %d of %d." % [index + 1, total], Notification.Type.SUCCESS)


func _on_interpreter_error(error: Interpreter.BlockError) -> void:
	SfxPlayer.play(SfxPlayer.FAIL)
	notifications.push(error.message, Notification.Type.ERROR)


func _on_interpreter_output(line: String) -> void:
	notifications.push(line, Notification.Type.LOG)


func _on_interpreter_running_changed() -> void:
	if is_instance_valid(_go_to_toolbox):
		_go_to_toolbox.disabled = Interpreter.is_running
