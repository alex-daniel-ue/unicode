class_name Puzzle
extends Control


const COMPLETE_SOUND := preload("res://audio/success.mp3")
const ERROR_SOUND := preload("res://audio/fail.mp3")
const THEME := preload("res://puzzle/ui/themes/main_theme.tres")
## The Go to Toolbox card (_toolbox_button): the brief's fonts, the blue of the
## game's pointers and log messages, and the toolbox tab's own icon.
const TOOLBOX_CARD_FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const TOOLBOX_CARD_BODY_FONT := preload("res://puzzle/ui/themes/fonts/AtkinsonHyperlegible-Regular.ttf")
const TOOLBOX_CARD_BLUE := Color(0.21960784, 0.7411765, 0.972549)
const TOOLBOX_ICON := preload("res://puzzle/ui/side panel/icons/pixelarticons--briefcase-plus.png")
## The assistant's tab button, which the assistant peeks out of to suggest
## itself (AssistantPeek), and the space over the canvas it peeks into.
const AI_BUTTON := "UserInterface/SideMenuLeft/ButtonContainer/AIAssistantMenuButton"
const MIDDLE_SPACE := "UserInterface/MiddleSpace"

## After which failed runs in a row the assistant offers to help
## (_suggest_assistant): these, then every NUDGE_EVERY after the last of them,
## so a student still stuck isn't left alone, and isn't nagged either.
const NUDGE_AFTER := [2, 4, 7]
const NUDGE_EVERY := 4
const TUTORIAL_OVERLAY := preload("res://puzzle/ui/tutorial/tutorial_overlay.tscn")
## Hidden when a level asks for the minimal UI (Level.minimal_ui): the first
## levels show only what they use, because everything at once lost people.
## The Information tab: the level's description. What the left panel shows when
## a level opens, after a guide that pointed into the toolbox, and when a run has
## no variables to show.
const INFORMATION_TAB := "UserInterface/SideMenuLeft/Panel/PuzzleInformation"
const ROOM_TAB := "UserInterface/SideMenuRight/Panel/PuzzleEnvironment"
const VALUE_BUBBLES := "ValueBubbles"
## How long the value tags from a solved room stay once the next room starts.
const ROOM_TAGS_FADE_AFTER := 0.6
const EXTRA_UI := [
	"UserInterface/SideMenuLeft/ButtonContainer/AIAssistantMenuButton",
	"UserInterface/SideMenuLeft/ButtonContainer/VariableWatcherMenuButton",
	"UserInterface/SideMenuRight/ButtonContainer/SpeedButton",
]

var failed_runs := 0
## Whether the room has been reset (reset_room()) since the last run, so the
## assistant reads it as at its start, not as the run left it.
var room_reset := false
var last_run_yaml := ""
var last_run_result := "The student hasn't pressed Play on this level yet."
var current_run_placed_blocks := 0

var _paused_before_menu := false
var _peek: AssistantPeek
## The guide on screen, if any, and the pages this level's guide has.
var _guide: TutorialOverlay
var _guide_pages: Array = []

@export var print_yaml := false

@export_group("Children")
@export var canvas: PuzzleCanvas
@export var side_panels: Array[SidePanel]
@export var information: Container
@export var toolbox: Toolbox
@export var ai_assistant: AIAssistant
@export var notif: NotificationStack
@export var level_viewport: SubViewport
@export var level_complete: LevelComplete
@export var pause_menu: PauseMenu

func _ready() -> void:
	side_panels[0].focus_content(get_node(INFORMATION_TAB) as Control)
	# focus_content, not show_menu: the panel has to know the room is what it
	# shows, or the room button's first press only "switches" to it.
	side_panels[1].focus_content(get_node(ROOM_TAB) as Control)

	canvas.add_child(RunPointer.new())
	_peek = AssistantPeek.new()
	_peek.button = get_node(AI_BUTTON) as Control
	get_node(MIDDLE_SPACE).add_child(_peek)
	# Once the assistant's panel is open, or a run starts, its suggestion has
	# been taken or is stale.
	ai_assistant.visibility_changed.connect(func() -> void:
		if ai_assistant.is_visible_in_tree():
			_peek.retreat())
	Interpreter.running_changed.connect(func() -> void:
		if Interpreter.is_running:
			_peek.retreat())

	if Game.level_scene != null:
		Game.level = Game.level_scene.instantiate() as Level
		configure_level()
	
	Interpreter.error_raised.connect(_on_interpreter_error)
	Interpreter.output_logged.connect(_on_interpreter_output)
	
	pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed)
	pause_menu.tutorials_requested.connect(_on_tutorials_requested)

## Perfectly functional; toggled on each "pause" action. Tested.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		open_menu()
	elif event.is_action_released("pause"):
		pause_menu.hide()

## Esc and the on-screen Esc button both land here. A run pauses behind the menu
## and gets its previous state back when the menu closes.
func open_menu() -> void:
	if pause_menu.visible:
		return
	_paused_before_menu = Interpreter.is_paused
	Interpreter.is_paused = true
	pause_menu.set_tutorial_state(not _guide_pages.is_empty(), is_instance_valid(_guide) and _guide.is_running())
	pause_menu.show()

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

func start_guide() -> void:
	if _guide_pages.is_empty():
		return
	if is_instance_valid(_guide):
		_guide.skip()
	_guide = TUTORIAL_OVERLAY.instantiate() as TutorialOverlay
	add_child(_guide)
	_guide.finished.connect(_on_guide_finished)
	_guide.start(self, _guide_pages)

## A guide about new blocks leaves the toolbox open. The task is what to read
## next, so the panel goes back to it.
func _on_guide_finished() -> void:
	if side_panels[0].shown_content == toolbox:
		show_information()

func show_information() -> void:
	side_panels[0].focus_content(get_node(INFORMATION_TAB) as Control)

## The level's functions, a define block each, to the left of Begin and one
## under another.
func _place_defines(begin_at: Vector2) -> void:
	var at := begin_at + FunctionDefinitions.OFFSET
	for node in Core.get_children_recursive(Game.level, true):
		if not node is FunctionDefinitions:
			continue
		for define in (node as FunctionDefinitions).define_blocks():
			canvas.add_child(define)
			define.position = at
			define.visible = true
			at.y += maxf(define.get_combined_minimum_size().y, 80.0) + FunctionDefinitions.GAP

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

## The way on from the Information tab once it has been read: to the blocks.
## The same as the toolbox's own tab button, so a guide waiting for that tab
## moves on too, and off while a program runs, as that button is. A card like
## the brief's own (LevelDescription._card), in the blue the game points with,
## with the toolbox tab's icon, so it reads as the brief's next step.
func _toolbox_button() -> Button:
	var button := Button.new()
	button.name = "GoToToolbox"
	button.theme_type_variation = &"InfoCardButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# The words and the icon as a row on the button, inside its margins. A
	# button doesn't size to what it holds, so it takes the row's height.
	var box := THEME.get_stylebox(&"normal", &"InfoCardButton")
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = box.content_margin_left
	row.offset_top = box.content_margin_top
	row.offset_right = -box.content_margin_right
	row.offset_bottom = -box.content_margin_bottom
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override(&"separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_card_label("NEXT STEP", TOOLBOX_CARD_FONT, 16, TOOLBOX_CARD_BLUE))
	var body := _card_label("Pick your blocks in the Toolbox.", TOOLBOX_CARD_BODY_FONT, 20, Color.WHITE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(body)
	row.add_child(words)
	var icon := TextureRect.new()
	icon.texture = TOOLBOX_ICON
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.modulate = TOOLBOX_CARD_BLUE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	button.add_child(row)
	var fit := func() -> void:
		button.custom_minimum_size.y = row.get_combined_minimum_size().y \
			+ box.content_margin_top + box.content_margin_bottom
	row.minimum_size_changed.connect(fit)
	fit.call()

	button.pressed.connect(func() -> void:
		side_panels[0].focus_content(toolbox)
		Tutorial.tab_shown.emit(toolbox))
	Interpreter.running_changed.connect(func() -> void:
		if is_instance_valid(button):
			button.disabled = Interpreter.is_running
			row.modulate.a = 0.45 if button.disabled else 1.0)
	return button

func _card_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _exit_tree() -> void:
	Interpreter.is_running = false
	Interpreter.clear_state()

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
	information.add_child(_toolbox_button())
	
	for block in Game.level.get_blocks():
		toolbox.add_block(block)
	var description := Game.level.description
	toolbox.mark_new(description.blocks, description.block_notes)

	for path: String in EXTRA_UI:
		(get_node(path) as Control).visible = not Game.level.minimal_ui
	
	# Block preset setup, for permanent, already-initialized Blocks in levels.
	# level.tscn ships a hidden BeginBlock, so get_preset() only comes back null on a
	# level whose LevelBlockPreset was emptied -- which reads at runtime as "Play does
	# nothing" rather than as the authoring mistake it is.
	var preset := Game.level.preset.get_preset()
	if preset == null:
		push_error("Level '%s': LevelBlockPreset has no Block child. It needs the begin block." % Game.level.name)
		notif.push("This level has no begin block, so it can't be played.", Notification.Type.ERROR)
	else:
		preset.reparent(canvas)
		preset.position = canvas.size / 2.
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

## Worked examples play themselves once, after a moment to take in the canvas.
## A child Timer rather than a SceneTreeTimer, so leaving the level early frees it
## instead of resuming into a freed Puzzle. Waits out the pause menu rather than
## starting behind it, and does nothing if the student already pressed Play.
func _auto_run() -> void:
	notif.push("Watch: this program runs by itself in a moment.", Notification.Type.LOG)
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_auto_run_timeout.bind(timer))
	add_child(timer)
	timer.start(Game.level.auto_run_delay)

func _on_auto_run_timeout(timer: Timer) -> void:
	if pause_menu.visible or (is_instance_valid(_guide) and _guide.is_running()):
		timer.start(0.5)
		return
	timer.queue_free()
	if Interpreter.is_running or level_complete.visible:
		return
	run_program()

func run_program() -> void:
	for err in Interpreter.active_errors:
		if is_instance_valid(err.block):
			err.block.visual.set_error(false)
	
	if Interpreter.is_running:
		notif.push("The program is already running.", Notification.Type.ERROR)
		return
	Interpreter.clear_state()
	
	var begin := _get_begin()
	if begin == null:
		notif.push("There is no begin block on the canvas.", Notification.Type.ERROR)
		return
	
	if begin.get_blocks().is_empty():
		notif.push("The begin block has no blocks under it. Attach a block to it first.", Notification.Type.ERROR)
		return
	
	last_run_yaml = canvas.serializer.yaml_serialize()
	room_reset = false

	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true
	
	var current_yaml := canvas.serializer.yaml_serialize()
	current_run_placed_blocks = Serializer.count_solid_blocks(current_yaml, true)
	
	var cleared := await Game.level.run_rooms(begin)
	if not cleared:
		_report_failure()
		failed_runs += 1
		if _should_nudge(failed_runs) and not Game.level.minimal_ui:
			_suggest_assistant()
		last_run_result = "Did not solve the level; the reason is in the output log."
	else:
		failed_runs = 0
		last_run_result = "Solved every room."
	
	Interpreter.is_running = false
	side_panels[1].keep_state = false
	Game.level.camera.frame()

## The room's Reset button: every room back as it was before the last run, the
## robot at its start, so the next run can be watched from the beginning. The
## blocks stay as they are.
func reset_room() -> void:
	if Interpreter.is_running:
		return
	Game.level.reset_rooms()
	room_reset = true
	notif.push("The room is back to how it started.", Notification.Type.LOG)

## Whether the `failures`th failed run in a row gets the assistant's offer:
## 2, 4, 7, then 11, 15, 19 and on.
func _should_nudge(failures: int) -> bool:
	var last: int = NUDGE_AFTER[-1]
	return failures in NUDGE_AFTER or (failures > last and (failures - last) % NUDGE_EVERY == 0)

## After a failed run: the assistant peeks out of its tab button and offers to
## look at the run. Taking the offer opens its panel, ready for a question.
func _suggest_assistant() -> void:
	_peek.suggest("Stuck? I can look at your last run.", func() -> void:
		side_panels[0].focus_content(ai_assistant)
		ai_assistant.prompt_for_question())

func describe_last_run() -> String:
	if last_run_yaml.is_empty():
		return last_run_result
	var changed := last_run_yaml != canvas.serializer.yaml_serialize()
	return last_run_result + (" The blocks have changed since that run." if changed else " The blocks are unchanged since that run.")

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null

func _on_level_completed() -> void:
	Interpreter.interrupted = true
	SfxPlayer.play(COMPLETE_SOUND)
	
	var stars := Game.level.calculate_stars(current_run_placed_blocks)
	Progress.record_completion(Game.level_id, stars)
	
	_show_level_complete(stars)

func _show_level_complete(stars: int) -> void:
	var card := level_complete.present(
		stars, current_run_placed_blocks, Game.level.get_star_par(), Game.level.star_slack, true
	)
	# The card is up before this returns; the summary fills in when it arrives.
	# last_run_yaml is the program as it was when Play was pressed: the winner.
	var summary := await ai_assistant.request_summary(
		last_run_yaml, current_run_placed_blocks, Game.level.get_star_par()
	)
	if is_instance_valid(level_complete):
		level_complete.show_summary(summary, card)

func _on_level_failed(reason: String) -> void:
	Interpreter.interrupted = true
	notif.push(reason, Notification.Type.ERROR)

func _report_failure() -> void:
	if not Interpreter.active_errors.is_empty():
		return
	if Game.level.has_failed:
		return
	
	const MESSAGE := "The program didn't finish."
	Interpreter.output_log.append(MESSAGE)
	notif.push(MESSAGE, Notification.Type.ERROR)

func _on_interpreter_error(error: Interpreter.Error) -> void:
	SfxPlayer.play(ERROR_SOUND)
	notif.push(error.message, Notification.Type.ERROR)

func _on_interpreter_output(line: String) -> void:
	notif.push(line, Notification.Type.LOG)

func _on_room_completed(index: int, total: int) -> void:
	if total <= 1: return
	# The last room's sound is the level's own.
	if index + 1 < total:
		SfxPlayer.play(SfxPlayer.NEXT_ROOM)
		(get_node(VALUE_BUBBLES) as ValueBubbles).fade_stale(ROOM_TAGS_FADE_AFTER)
	notif.push("You solved Room %d of %d." % [index + 1, total], Notification.Type.SUCCESS)
