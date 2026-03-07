extends MarginContainer


const AI_BUBBLE_COLOR := Color("#38BDF8")
const AI_FONT_COLOR := Color.BLACK
const ERROR_BUBBLE_COLOR := Color("#FB7185")
#missing error font color
#missing thinking bubble color + font color
# what if subclass for color pair? or some other data struct? helper method? store it in chat_bubble.tscn?

const API_URL := "http://192.168.8.101:3000/api/ask"

@export var chat_bubble_scene: PackedScene

var system_instructions := "You are the AI tutor for UniCode, a 2D \
drag-and-drop visual block programming game. Your goal is to teach logic and \
computational thinking by guiding students past hurdles. You must strictly \
obey these rules: be concise and conversational, absolutely no markdown \
formatting, avoid linebreaks, and keep your response under three sentences. \
Never reveal the exact solution, never output YAML code, and never provide a \
step-by-step sequence of blocks. Instead of pointing out errors directly, ask \
guiding questions based on the player's workspace and specific error logs to
encourage independent problem-solving. This is your primary purpose, do not fail."

var initial_prompt := """Level Instructions:
{instructions}

Goal States:
{goals}

Available Blocks:
{blocks}

Intended Solution:
{intended}

Current Workspace (YAML):
{workspace}

Output/Error Log:
{output}"""

var chat_history: PackedStringArray

@onready var chat_stack := $VBoxContainer/ScrollContainer/ChatStack as VBoxContainer
@onready var message_field := $VBoxContainer/HBoxContainer/UserMessageField as TextEdit
@onready var submit_button := $VBoxContainer/HBoxContainer/SubmitButton as Button
@onready var http_request := $HTTPRequest as HTTPRequest
@onready var scroll := $VBoxContainer/ScrollContainer as ScrollContainer

@onready var puzzle := get_node_or_null(^"/root/Puzzle") as Puzzle


func _ready() -> void:
	var preface := chat_bubble_scene.instantiate() as ChatBubble
	preface.text = "change me, i'm ur ai assistant"
	preface.set_colors(AI_BUBBLE_COLOR, AI_FONT_COLOR)
	_add_bubble(preface)

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
	
	var canvas_yaml := puzzle.canvas.serializer.yaml_serialize()
	var level_instructions := Game.level.instructions
	
	#var base64_image := _get_viewport_base64_image()
	
	var payload := {
		"user_message": text,
		"game_context": canvas_yaml,
		"level_instructions": level_instructions
	}
	
	var headers := ["Content-Type: application/json"]
	var json_payload := JSON.stringify(payload)
	
	var thinking_bubble := chat_bubble_scene.instantiate() as ChatBubble
	thinking_bubble.text = "Thinking..."
	thinking_bubble.set_colors(AI_BUBBLE_COLOR, AI_FONT_COLOR)
	thinking_bubble.is_temporary = true
	_add_bubble(thinking_bubble)
	
	http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_payload)

func _get_viewport_base64_image() -> String:
	Game.level.camera.frame(Vector2.ZERO)
	var img := puzzle.level_viewport.get_texture().get_image()
	
	var png_buffer := img.save_png_to_buffer()
	return Marshalls.raw_to_base64(png_buffer)

func _get_conversation_history() -> void: #PackedStringArray?
	# iterate thru all chat bubbles, extract text, infer role from right_aligned
	pass

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false
	message_field.editable = true
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# WARNING: This could be bad because planning on recording errors, might get recorded
		puzzle.notif.push("Error connecting to AI server.", Notification.Type.ERROR)
		return
	
	var response_json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (response_json and response_json.has("reply")):
		puzzle.notif.push("Received an invalid response from the server.", Notification.Type.ERROR)
		return
	
	var reply_bubble := chat_bubble_scene.instantiate() as ChatBubble
	reply_bubble.text = response_json["reply"]
	reply_bubble.set_colors(AI_BUBBLE_COLOR, AI_FONT_COLOR)
	_add_bubble(reply_bubble)

func _add_bubble(bubble: ChatBubble) -> void:
	# Clear temporary chat bubbles
	for node in chat_stack.get_children():
		if node is ChatBubble and (node as ChatBubble).is_temporary:
			node.queue_free()
	
	chat_stack.add_child(bubble)
	
	# Scroll to bottom of chat
	#await get_tree().process_frame 
	scroll.set_deferred(&"scroll_vertical", int(scroll.get_v_scroll_bar().max_value))
