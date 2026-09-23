class_name Puzzle
extends Control


const COMPLETE_SOUND := preload("res://audio/success.mp3")
const ERROR_SOUND := preload("res://audio/fail.mp3")

const NUDGE_AFTER := [3, 7]

var failed_runs := 0
var last_run_yaml := ""
var last_run_result := "The student hasn't pressed Play on this level yet."
var current_run_placed_blocks := 0

var _paused_before_menu := false

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
@export var pause_menu: PopupPanel

func _ready() -> void:
	side_panels[0].show_menu(true)
	side_panels[1].show_menu(true)
	
	if Game.level_scene != null:
		Game.level = Game.level_scene.instantiate() as Level
		configure_level()
	
	Interpreter.error_raised.connect(_on_interpreter_error)
	Interpreter.output_logged.connect(_on_interpreter_output)
	
	pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed)

## Perfectly functional; toggled on each "pause" action. Tested.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_paused_before_menu = Interpreter.is_paused
		Interpreter.is_paused = true
		pause_menu.show()
	elif event.is_action_released("pause"):
		pause_menu.hide()

func _on_pause_menu_visibility_changed() -> void:
	if not pause_menu.visible:
		Interpreter.is_paused = _paused_before_menu

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
		content.reparent(information)
	
	for block in Game.level.get_blocks():
		toolbox.add_block(block)
	
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
	
	if Game.level.tutorial_overlay != null:
		var overlay := Game.level.tutorial_overlay.instantiate() as TutorialOverlay
		add_child(overlay)
		overlay.attach(self)

func run_program() -> void:
	for err in Interpreter.active_errors:
		if is_instance_valid(err.block):
			err.block.visual.set_error(false)
	
	if Interpreter.is_running:
		notif.push("Program is already running.", Notification.Type.ERROR)
		return
	Interpreter.clear_state()
	
	var begin := _get_begin()
	if begin == null:
		notif.push("No begin block on Canvas.", Notification.Type.ERROR)
		return
	
	if begin.get_blocks().is_empty():
		notif.push("Begin has no blocks under it.", Notification.Type.ERROR)
		return
	
	last_run_yaml = canvas.serializer.yaml_serialize()
	
	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true
	
	var current_yaml := canvas.serializer.yaml_serialize()
	current_run_placed_blocks = Serializer.count_solid_blocks(current_yaml, true)
	
	var cleared := await Game.level.run_rooms(begin)
	if not cleared:
		_report_failure()
		failed_runs += 1
		if failed_runs in NUDGE_AFTER:
			notif.push(
				"Stuck? The assistant can look at your last run.",
				Notification.Type.LOG,
				func() -> void:
					side_panels[0].focus_content(ai_assistant)
					ai_assistant.prompt_for_question()
			)
		last_run_result = "Did not solve the level; the reason is in the output log."
	else:
		failed_runs = 0
		last_run_result = "Solved every room."
	
	Interpreter.is_running = false
	side_panels[1].keep_state = false
	Game.level.camera.frame()

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
	var summary := await ai_assistant.request_summary(last_run_yaml)
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
	notif.push("Room %d of %d solved." % [index + 1, total], Notification.Type.SUCCESS)
