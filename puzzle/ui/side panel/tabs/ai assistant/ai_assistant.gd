extends MarginContainer


const API_URL := "http://127.0.0.1:3000/api/ask"

@export var chat_bubble_scene: PackedScene

@export_group("Bubble Themes")
@export var bubble_theme_ai: BubbleTheme
@export var bubble_theme_error: BubbleTheme
@export var bubble_theme_thinking: BubbleTheme

var system_instructions := "You are the AI tutor for UniCode, a 2D drag-and-drop visual block programming game. Your goal is to teach logic and computational thinking by guiding students past hurdles. You must strictly obey these rules: be concise and conversational, absolutely no Markdown nor other formatting/syntax, only use plain English, avoid linebreaks, and respond in under 3-4 sentences. Never reveal the exact solution, never output YAML code, and never provide a step-by-step sequence of blocks. The workspace provided in the latest user message represents the current state of the game. If the user mentions previous states, infer the changes by comparing the current state with their previous messages, but be transparent that you are inferring. Instead of pointing out errors directly, ask guiding questions based on the player's workspace and specific error logs to encourage independent problem-solving. This is your primary purpose, do not fail."

#Goal States:
#{goals}
#
#Available Blocks:
#{blocks}

var initial_prompt := """Level Instructions:
{instructions}

Current Workspace (YAML):
```
{workspace}
```

Intended Solution:
```
{intended}
```

Output Log:
{output}

Active Errors:
{errors}"""

var final_prompt := """=== CURRENT GAME STATE ===
{context}

=== USER MESSAGE ===
{message}
"""

var chat_history: PackedStringArray

@export_group("Children")
@export var chat_stack: VBoxContainer
@export var message_field: TextEdit
@export var submit_button: Button
@export var http_request: HTTPRequest
@export var scroll: ScrollContainer

@onready var puzzle := get_node_or_null(^"/root/Puzzle") as Puzzle


func _ready() -> void:
	var preface := chat_bubble_scene.instantiate() as ChatBubble
	preface.text = "Hi! I'm your AI Assistant. How can I help you with this level?"
	preface.bubble_theme = bubble_theme_ai
	_add_bubble(preface)
	
	Interpreter.running_changed.connect(_on_interpreter_running_changed)

func _on_submit_pressed() -> void:
	var text := message_field.text.strip_edges()
	if text.is_empty():
		return
	
	message_field.text = ""
	
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

func _send_api_request(msg: String) -> void:
	var canvas_yaml := puzzle.canvas.serializer.yaml_serialize()
	
	var level_instructions := "N/A"
	var intended_solution := "N/A"
	if is_instance_valid(Game.level):
		level_instructions = Game.level.instructions
		intended_solution = Game.level.intended_solution
	
	var output_log := "N/A"
	if not Interpreter.output_log.is_empty():
		output_log = "\n".join(Interpreter.output_log)
	
	var errors := "N/A"
	if not Interpreter.active_errors.is_empty():
		errors = "\n\n".join(Interpreter.active_errors.map(str))
	
	var dynamic_context := initial_prompt.format({
		instructions = level_instructions,
		workspace = canvas_yaml,
		intended = intended_solution,
		output = output_log,
		errors = errors
	})
	
	var contents := _get_conversation_history()
	
	var final_part := [{text = final_prompt.format({
		context = dynamic_context,
		message = msg
	})}]
	
	var base64_image := _get_viewport_base64_image()
	if not base64_image.is_empty():
		final_part.append({
			inline_data = {
				mime_type = "image/png",
				data = base64_image
			}
		})
	
	contents.append({
		role = "user",
		parts = final_part
	})
	
	var payload := {
		system_instruction = system_instructions,
		contents = contents
	}
	
	var headers := ["Content-Type: application/json"]
	var json_payload := JSON.stringify(payload)
	
	#print(JSON.stringify(payload, '\t'))
	
	http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_payload)

func _get_viewport_base64_image() -> String:
	if not (is_instance_valid(Game.level) and is_instance_valid(puzzle.level_viewport)):
		return ""
	
	Game.level.camera.frame(Vector2.ZERO)
	
	var img := puzzle.level_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return ""
	
	var png_buffer := img.save_png_to_buffer()
	return Marshalls.raw_to_base64(png_buffer)

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
	
	valid_bubbles.pop_back() # Remove current user message
	
	for bubble in valid_bubbles:
		history.append({
			role = "user" if bubble.right_aligned else "model",
			parts = [{text = bubble.text}]
		})
	
	return history

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false
	message_field.editable = true
	
	_clear_temporary()
	
	var response_json: Variant = null
	if body.size() > 0:
		var body_string := body.get_string_from_utf8()
		response_json = JSON.parse_string(body_string)
	
	var has_reply := response_json != null \
		and typeof(response_json) == TYPE_DICTIONARY \
		and response_json.has("reply") as bool
	
	var err_msg := ""
	if result != HTTPRequest.RESULT_SUCCESS:
		err_msg = "Network error connecting to AI server."
	elif response_code != 200:
		err_msg = "Server returned error code: %d" % response_code
		if has_reply:
			err_msg = "Server error: " + str(response_json["reply"])
	elif not has_reply:
		err_msg = "Received an invalid response format from the server."
	
	if not err_msg.is_empty():
		puzzle.notif.push(err_msg, Notification.Type.ERROR)
		
		# Find latest user message and flag as error, flag temporary
		for idx in range(chat_stack.get_child_count()-1, 0, -1):
			var bubble := chat_stack.get_child(idx) as ChatBubble
			if bubble.right_aligned:
				bubble.is_temporary = true
				bubble.bubble_theme = bubble_theme_error
				break
		
		return
	
	var reply_bubble := chat_bubble_scene.instantiate() as ChatBubble
	reply_bubble.text = response_json["reply"]
	reply_bubble.bubble_theme = bubble_theme_ai
	_add_bubble(reply_bubble)

func _add_bubble(bubble: ChatBubble) -> void:
	_clear_temporary()
	chat_stack.add_child(bubble)
	
	var bottom := int(scroll.get_v_scroll_bar().max_value)
	scroll.set_deferred(&"scroll_vertical", bottom)

func _clear_temporary() -> void:
	for node in chat_stack.get_children():
		if node is ChatBubble and (node as ChatBubble).is_temporary:
			node.queue_free()

func _on_interpreter_running_changed() -> void:
	submit_button.disabled = Interpreter.is_running
