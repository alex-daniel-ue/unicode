class_name AIAssistant
extends MarginContainer


const API_URL := "http://127.0.0.1:3000/api/hint"
const CLIENT_TOKEN := "must-match-UNICODE_CLIENT_TOKEN"
const TIMEOUT_DURATION := 30.

@export var chat_bubble_scene: PackedScene

@export_group("Bubble Themes")
@export var bubble_theme_ai: BubbleTheme
@export var bubble_theme_error: BubbleTheme
@export var bubble_theme_thinking: BubbleTheme

@export_group("Children")
@export var chat_stack: VBoxContainer
@export var message_field: TextEdit
@export var submit_button: Button
@export var reset_button: Button
@export var http_request: HTTPRequest
@export var scroll: ScrollContainer

var system_instructions := "You are the AI tutor for UniCode, a 2D drag-and-drop visual block programming game. Your goal is to teach logic and computational thinking by guiding students past hurdles. You must strictly obey these rules: be concise and conversational, absolutely no Markdown nor other formatting/syntax, only use plain English, avoid linebreaks, and respond in under 3 sentences. Never reveal the exact solution, never output YAML code, and never provide a step-by-step sequence of blocks. The workspace provided in the latest user message represents the current state of the game. If the user mentions previous states, infer the changes by comparing the current state with their previous messages, but be transparent that you are inferring. Instead of pointing out errors directly, ask guiding questions based on the player's workspace and specific error logs to encourage independent problem-solving. If the user isn't cooperating or the conversation is off-topic, you must output `RESET`.\nThis is your primary purpose, do not fail."

#Goal States:
#{goals}

var initial_prompt := """Current game state:
Level instructions:
{instructions}

Available Blocks:
{blocks}

Current workspace (YAML):
```
{workspace}
```

Intended solution:
```
{intended}
```

Recent output log:
{output}

Active errors:
{errors}"""

var chat_history: PackedStringArray
var in_timeout := false

@onready var puzzle := get_node_or_null(^"/root/Puzzle") as Puzzle


func _ready() -> void:
	http_request.timeout = 20.
	
	_reset_chat()
	Interpreter.running_changed.connect(_on_interpreter_running_changed)

#region UI interaction
func _on_submit_pressed() -> void:
	var text := message_field.text.strip_edges()
	if text.is_empty():
		return
	
	message_field.text = ""
	
	if not Tutorial.shift_enter_shown:
		Tutorial.shift_enter_shown = true
		puzzle.notif.push(
			"You can send messages with SHIFT+ENTER!",
			Notification.Type.LOG
		)
	
	var user_bubble := chat_bubble_scene.instantiate() as ChatBubble
	user_bubble.text = text
	user_bubble.right_aligned = true
	_add_bubble(user_bubble)
	
	submit_button.disabled = true
	message_field.editable = false
	
	var thinking_bubble := chat_bubble_scene.instantiate() as ChatBubble
	thinking_bubble.text = "Thinking..."
	thinking_bubble.bubble_theme = bubble_theme_thinking
	thinking_bubble.is_temporary = true
	_add_bubble(thinking_bubble)
	
	_send_api_request(text)

func _reset_chat() -> void:
	http_request.cancel_request()
	
	submit_button.disabled = false
	message_field.editable = true
	
	reset_button.disabled = true
	
	for child in chat_stack.get_children():
		child.queue_free()
	
	var preface := chat_bubble_scene.instantiate() as ChatBubble
	preface.text = "Hi! I'm your AI Assistant. How can I help you with this level?"
	preface.bubble_theme = bubble_theme_ai
	_add_bubble(preface)

func _on_interpreter_running_changed() -> void:
	if in_timeout:
		return
	
	submit_button.disabled = Interpreter.is_running
	reset_button.disabled = Interpreter.is_running
#endregion

#region API payload, prompt generation
func _send_api_request(msg: String) -> void:
	var level: Level = Game.level if is_instance_valid(Game.level) else null
	var image := await _get_viewport_base64_image()
	var history: Array[Dictionary] = []
	for child in chat_stack.get_children():
		var bubble := child as ChatBubble
		if bubble and not bubble.is_temporary and not bubble.is_queued_for_deletion():
			history.append({role = "user" if bubble.right_aligned else "model", text = bubble.text})
	history.pop_back()  # the current message travels in `message`
	var payload := {
		session_id = Game.session_id,
		level_id = level.scene_file_path.get_file().get_basename() if level else "",
		message = msg,
		history = history,
		screenshot_jpeg_b64 = image,
		context = {
			instructions = level.description.get_raw() if level else "N/A",
			blocks = _get_available_blocks_doc(),
			workspace = puzzle.canvas.serializer.yaml_serialize(),
			intended_solution = level.intended_solution if level else "N/A",
			last_run = puzzle.describe_last_run(),
			last_run_program = puzzle.last_run_yaml,
			output_log = "\n".join(Interpreter.output_log.slice(-40)),
			robot = _robot_state(),
		},
	}
	var headers := ["Content-Type: application/json", "X-UniCode-Token: " + CLIENT_TOKEN]
	
	if OS.is_debug_build():
		var shown := payload.duplicate(true)
		shown.screenshot_jpeg_b64 = "<%d base64 chars>" % str(payload.screenshot_jpeg_b64).length()
		print("── hint request ──\n", JSON.stringify(shown, "  ", false))
	
	if http_request.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		_on_hint_failed("Couldn't reach the hint helper.")

func _get_available_blocks_doc() -> String:
	if not is_instance_valid(Game.level):
		return "N/A"
	
	var sections: PackedStringArray
	
	var toolbox_lines := _format_block_data(
		Game.level.get_block_data(),
		func(data: BlockData) -> bool: return data.toolbox
	)
	sections.append(
		"\n".join(toolbox_lines) if not toolbox_lines.is_empty()
		else "(none - everything this level needs is already on the canvas)"
	)
	
	# Presets are filtered on syntax rather than on `toolbox`, because
	# get_preset() sets toolbox = false on every block it hands over, and because
	# the walk also turns up parameter sockets and the Begin block, none of which
	# are authored vocabulary. Scaffolding has no syntax; real blocks do.
	var preset_lines := _format_block_data(
		Game.level.preset.preset_data,
		func(data: BlockData) -> bool: return not data.syntax.is_empty()
	)
	if not preset_lines.is_empty():
		sections.append(
			"\nAlready on the canvas and locked (the student cannot copy or delete these):\n"
			+ "\n".join(preset_lines)
		)
	
	return "\n".join(sections)

func _format_block_data(all_data: Array[BlockData], include: Callable) -> PackedStringArray:
	var lines: PackedStringArray
	var seen: Dictionary
	for data in all_data:
		if seen.has(data.name) or not include.call(data):
			continue
		seen[data.name] = true
		var s := data.syntax if not data.syntax.is_empty() else data.text
		var d := data.description if not data.description.is_empty() else "No description."
		lines.append("- %s: %s" % [s, d])
	return lines

func _get_viewport_base64_image() -> String:
	if not (is_instance_valid(Game.level) and is_instance_valid(puzzle.level_viewport)):
		return ""
	
	await RenderingServer.frame_post_draw
	
	var img := puzzle.level_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return ""
	
	if img.get_width() > 768:
		img.resize(768, roundi(768.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	return Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.8))

func _get_conversation_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = [{
		role = "user",
		parts = [{text = "Hello!"}]
	}]
	
	var valid_bubbles: Array[ChatBubble]
	for child in chat_stack.get_children():
		if child is ChatBubble:
			var bubble := child as ChatBubble
			if not bubble.is_temporary:
				valid_bubbles.append(bubble)
	
	valid_bubbles.pop_back()  # Remove current user message
	
	for bubble in valid_bubbles:
		history.append({
			role = "user" if bubble.right_aligned else "model",
			parts = [{text = bubble.text}]
		})
	
	return history
#endregion

func _on_request_completed(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false
	message_field.editable = true
	_clear_temporary()
	
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	
	if OS.is_debug_build():
		print("── hint response (HTTP %d) ──\n" % _code,
			JSON.stringify(data, "  ", false) if data != null else body.get_string_from_utf8())
	
	if result != HTTPRequest.RESULT_SUCCESS or typeof(data) != TYPE_DICTIONARY:
		_on_hint_failed("Couldn't reach the hint helper. Check the internet connection.")
		return
	
	var reply := str(data.get("reply", ""))
	match str(data.get("status", "")):
		"ok", "off_topic":
			_add_ai_bubble(reply)
		"blocked":
			_on_hint_failed(reply)
			_apply_safety_timeout(10)
		_:
			_on_hint_failed(reply if not reply.is_empty() else "The hint helper isn't available right now.")

func prompt_for_question() -> void:
	message_field.placeholder_text = "What did you expect to happen, and what happened instead?"
	message_field.grab_focus()

#region UI helper methods
func _flag_latest_user_message() -> void:
	for idx in range(chat_stack.get_child_count() - 1, -1, -1):
		var bubble := chat_stack.get_child(idx) as ChatBubble
		if bubble.right_aligned:
			# Stays temporarily on the screen as red text, deleted on next submission
			bubble.is_temporary = true
			bubble.bubble_theme = bubble_theme_error
			break

func _add_bubble(bubble: ChatBubble) -> void:
	_clear_temporary()
	
	for node in chat_stack.get_children():
		if not node.is_queued_for_deletion():
			reset_button.disabled = false
			break
	
	chat_stack.add_child(bubble)
	
	var bottom := int(scroll.get_v_scroll_bar().max_value)
	scroll.set_deferred(&"scroll_vertical", bottom)

func _add_ai_bubble(text: String, temporary := false) -> void:
	var bubble := chat_bubble_scene.instantiate() as ChatBubble
	bubble.text = text
	bubble.bubble_theme = bubble_theme_ai
	_add_bubble(bubble)
	bubble.is_temporary = temporary  # after _add_bubble, which clears temporaries

func _clear_temporary() -> void:
	for node in chat_stack.get_children():
		if node is ChatBubble and (node as ChatBubble).is_temporary:
			node.queue_free()

func _apply_safety_timeout(duration := TIMEOUT_DURATION) -> void:
	in_timeout = true
	
	submit_button.disabled = true
	reset_button.disabled = true
	message_field.editable = false
	
	for i in range(duration, 0, -1):
		if not in_timeout:
			return
		
		message_field.placeholder_text = "Timed out. Wait %ds..." % i
		await get_tree().create_timer(1.0).timeout
	
	if in_timeout:
		in_timeout = false
		message_field.placeholder_text = "Type here..."
		message_field.editable = true
		submit_button.disabled = Interpreter.is_running
		reset_button.disabled = Interpreter.is_running

func _on_hint_failed(text: String) -> void:
	_add_ai_bubble(text, true)
	_flag_latest_user_message()  # flag AFTER adding, or _add_bubble would delete the red message

func _robot_state() -> String:
	var robot := get_tree().get_first_node_in_group(&"robot") as Node2D  # robot.gd: add_to_group(&"robot") in _ready
	if robot == null:
		return "N/A"
	var names := {Vector2.UP: "up", Vector2.DOWN: "down", Vector2.LEFT: "left", Vector2.RIGHT: "right"}
	return "tile %s, facing %s" % [Vector2i((robot.position / 32.0).floor()), names.get(robot.get(&"facing_direction"), "?")]
#endregion
