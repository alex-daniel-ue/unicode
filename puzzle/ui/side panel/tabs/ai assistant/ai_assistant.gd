extends MarginContainer


const API_URL := "http://192.168.8.101:3000/api/ask"

@export var chat_bubble_scene: PackedScene

@onready var chat_stack := %ChatStack as VBoxContainer
@onready var message_field := %UserMessageField as TextEdit
@onready var submit_button := %SubmitButton as Button
@onready var http_request := %HTTPRequest as HTTPRequest

@onready var puzzle := $"/root/Puzzle" as Puzzle


func _ready() -> void:
	_add_bubble("Hi! I'm your AI Assistant. How can I help you with this level?", true)

func _on_submit_pressed() -> void:
	var text := message_field.text.strip_edges()
	if text.is_empty():
		return
	
	message_field.text = ""
	_add_bubble(text, false)
	
	submit_button.disabled = true
	message_field.editable = false
	
	var canvas_yaml := puzzle.canvas.serializer.yaml_serialize()
	var level_instructions := Game.level.instructions if is_instance_valid(Game.level) else ""
	
	var base64_image := ""
	if is_instance_valid(puzzle.level_viewport):
		Game.level.camera.frame(Vector2.ZERO)
		var img := puzzle.level_viewport.get_texture().get_image()
		var png_buffer := img.save_png_to_buffer()
		base64_image = Marshalls.raw_to_base64(png_buffer)
	
	var payload := {
		"user_message": text,
		"game_context": canvas_yaml,
		"level_instructions": level_instructions
	}
	
	var headers := ["Content-Type: application/json"]
	var json_payload := JSON.stringify(payload)
	
	_add_bubble("Thinking...", true) # Add a temporary loading bubble
	
	http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_payload)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false
	message_field.editable = true
	
	var loading_bubble := chat_stack.get_child(chat_stack.get_child_count() - 1)
	if loading_bubble and loading_bubble.text == "Thinking...":
		loading_bubble.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		puzzle.notif.push("Error connecting to AI server.", Notification.Type.ERROR)
		return
	
	var response_json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_json and response_json.has("reply"):
		_add_bubble(response_json["reply"], true)
	else:
		_add_bubble("Received an invalid response from the server.", true, Color("#FB7185"))

func _add_bubble(text: String, is_ai: bool, color_override := Color.TRANSPARENT) -> void:
	var bubble = chat_bubble_scene.instantiate()
	chat_stack.add_child(bubble)
	
	bubble.text = text
	bubble.left_aligned = is_ai
	
	if is_ai:
		bubble.bubble_color = color_override if color_override != Color.TRANSPARENT else Color("#38BDF8")
		bubble.text_color = Color.BLACK
	else:
		bubble.bubble_color = Color("#E2E8F0")
		bubble.text_color = Color.BLACK
	
	await get_tree().process_frame
	
	var scroll := chat_stack.get_parent() as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
