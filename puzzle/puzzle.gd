class_name Puzzle
extends Control


signal running_state_changed(to: bool)

enum NotificationType {
	LOG,
	ERROR,
	SUCCESS
}

const MAX_DEPTH := 1000
const MAX_LOOPS := 10000
const SLOW_DELAY := 0.5
const FAST_DELAY := 0.15
const NOTIF_DURATION := 2.0

const LEVEL_SELECT_SCENE := preload("res://menus/level select/level_select.tscn")
const COMPLETE_SOUND := preload("res://audio/success.mp3")

static var is_running := false
static var is_fast := false
static var interpret_delay := SLOW_DELAY
static var has_errored := false

#region Exports
@export var canvas: ColorRect
@export var side_panels: Array[Panel]
@export var information: Label
@export var toolbox: MarginContainer
@export var notification_stack: VBoxContainer
@export var level_viewport: SubViewport
@export var level_complete_popup: PopupPanel
@export var stars: HBoxContainer
@export var pause_menu: PopupPanel

@export_group("Buttons")
@export var run_button: Button
@export var stop_button: Button
@export var speed_button: Button
@export var trash_button: Button
#endregion

# NOTE: Avoid refactoring this. This is perfectly fine.
var errored_blocks: Array[Block]
var level: Level


func _ready() -> void:
	side_panels[0].show_menu(true)
	side_panels[1].show_menu(true)
	
	if Game.pending_level != null:
		configure_level()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.show()
	elif event.is_action_released("pause"):
		pause_menu.hide()

func configure_level() -> void:
	level = Game.pending_level.instantiate() as Level
	level.completed.connect(_on_level_completed)
	level.failed.connect(_on_level_failed)
	information.text = level.instructions
	
	for node in level_viewport.get_children():
		node.queue_free()
	level_viewport.add_child(level)
	
	for block in level.get_blocks():
		if block is CapBlock and block.is_type(NestedData.Type.BEGIN):
			canvas.add_child(block)
			block.position = canvas.size / 2.
			continue
		
		toolbox.add_block(block)
	
	Game.pending_level = null

func run_program() -> void:
	#print(canvas.serializer.yaml_serialize())
	for block in errored_blocks:
		if is_instance_valid(block):
			block.visual.set_error(false)
	errored_blocks.clear()
	
	if is_running:
		notification_stack.add(
			"Program is already running.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)
		return
	
	var begin := _get_begin()
	if begin == null:
		notification_stack.add(
			"No begin block on Canvas.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)
		return
	
	level.visuals.position = Vector2.ZERO
	level.reset_state()
	set_running_state(true)
	side_panels[0].show_menu(false)
	side_panels[1].show_menu(true)
	
	for panel in side_panels:
		panel.keep = true
	
	await begin.function.run()
	
	set_running_state(false)
	for panel in side_panels:
		panel.keep = false

func set_running_state(to: bool) -> void:
	is_running = to
	
	run_button.disabled = to
	trash_button.disabled = to
	
	stop_button.disabled = not to
	speed_button.disabled = not to
	
	if not to:
		has_errored = false
	
	running_state_changed.emit(is_running)

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null

func hide_side_menus() -> void:
	for panel in side_panels:
		if panel.has_method(&"show_menu"):
			panel.show_menu(false)

func _on_block_errored(block: Block) -> void:
	has_errored = true
	if not errored_blocks.has(block):
		errored_blocks.append(block)

func _on_notif_pushed(message: String, type: NotificationType) -> void:
	notification_stack.add(message, 2., type)

func _on_level_completed() -> void:
	has_errored = true
	
	var star_count := 1
	SfxPlayer.play(COMPLETE_SOUND)
	
	#region Put this entire section into its own .gd script, "level_complete_popup" probably
	var blocks := 0
	for node in canvas.get_children():
		if node is Block:
			var descendants = Core.get_children_recursive(node, false)
			for descendant in descendants:
				if descendant is Block and descendant.data.top_notch:
					blocks += 1
	
	for child in stars.get_children():
		child.queue_free()
	
	var FILLED_STAR := load("res://puzzle/ui/level complete popup/star_filled.png")
	var EMPTY_STAR := load("res://puzzle/ui/level complete popup/star_empty.png")
	
	var star := TextureRect.new()
	star.texture = FILLED_STAR
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.custom_minimum_size = Vector2(50, 50)
	stars.add_child(star)
	
	for threshold in [level.two_star_threshold, level.three_star_threshold]:
		star = TextureRect.new()
		star.texture = EMPTY_STAR
		if blocks <= threshold:
			star.texture = FILLED_STAR
			star_count += 1
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(50, 50)
		stars.add_child(star)
	#endregion
	
	Game.update_level_stars(level.scene_file_path, star_count)
	level_complete_popup.show()

func _on_level_failed() -> void:
	has_errored = true
	_on_notif_pushed("Level failed!", NotificationType.ERROR)

func _on_stop_button_pressed() -> void:
	if is_running:
		has_errored = true
		notification_stack.add(
			"Program terminated.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)

func _on_speed_button_pressed() -> void:
	interpret_delay = SLOW_DELAY if is_fast else FAST_DELAY
	is_fast = not is_fast

func _on_return_button_pressed() -> void:
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_packed(LEVEL_SELECT_SCENE)
