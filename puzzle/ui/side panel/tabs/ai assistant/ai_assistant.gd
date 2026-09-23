class_name AIAssistant
extends MarginContainer


const CONFIG_FILE := "unicode_ai.cfg"
const DEFAULT_URL := "http://127.0.0.1:3000/api/hint"
const DEFAULT_PLACEHOLDER := "Type here..."

const REQUEST_TIMEOUT := 35.0
const SUMMARY_TIMEOUT := 12.0
const BLOCKED_TIMEOUT := 10
const RATE_LIMIT_TIMEOUT := 15
const SHOT_WIDTH := 768
const SHOT_BACKGROUND := Color(0.11, 0.11, 0.14)
const LOG_LINES := 40

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

var api_url := DEFAULT_URL
var fallback_url := ""
var summary_url := ""
var client_token := ""

var in_timeout := false
var _awaiting_reply := false
var _pending_json := ""
var _tried_fallback := false

## The prompt shown in the empty field: the default, or the nudge's scaffolding
## question. The pool status is added to it, never written over it.
var _base_placeholder := DEFAULT_PLACEHOLDER
## True while the message in flight has been paid for from the HintPool, so a
## request that never reached the model can be refunded exactly once.
var _charged := false
var _pool_ticker: Timer

## Screenshot diagnostics, printed with the request in debug builds.
var _shot_note := ""
var _shot_bytes := 0

var _summary_http: HTTPRequest

@onready var puzzle := get_node_or_null(^"/root/Puzzle") as Puzzle


func _ready() -> void:
	_load_ai_config()
	http_request.timeout = REQUEST_TIMEOUT
	http_request.use_threads = true
	
	_reset_chat()
	Interpreter.running_changed.connect(_refresh_busy_state)
	Interpreter.paused_changed.connect(_refresh_busy_state)
	
	# The pool regenerates by the clock, so the field has to be re-read once a
	# second while it is empty or the countdown in the placeholder would freeze.
	_pool_ticker = Timer.new()
	_pool_ticker.wait_time = 1.0
	_pool_ticker.autostart = true
	_pool_ticker.timeout.connect(_refresh_busy_state)
	add_child(_pool_ticker)
	
	_summary_http = HTTPRequest.new()
	_summary_http.timeout = SUMMARY_TIMEOUT
	_summary_http.use_threads = true
	add_child(_summary_http)

func _exit_tree() -> void:
	http_request.cancel_request()
	if is_instance_valid(_summary_http):
		_summary_http.cancel_request()

func _load_ai_config() -> void:
	var folder := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir()
	
	var config := ConfigFile.new()
	if config.load(folder.path_join(CONFIG_FILE)) != OK:
		push_warning("No %s found; falling back to %s." % [CONFIG_FILE, DEFAULT_URL])
		return
	
	api_url = config.get_value("ai", "url", api_url)
	fallback_url = config.get_value("ai", "fallback_url", fallback_url)
	client_token = config.get_value("ai", "token", client_token)
	summary_url = config.get_value("ai", "summary_url", summary_url)

#region UI interaction
func _on_submit_pressed() -> void:
	if _awaiting_reply:
		return
	
	var text := message_field.text.strip_edges()
	if text.is_empty():
		return
	
	if Interpreter.is_running:
		return
	if not HintPool.take():
		puzzle.notif.push(
			"Out of questions for now. The next one comes back in %s." % _clock(HintPool.seconds_to_next()),
			Notification.Type.LOG
		)
		_refresh_busy_state()
		return
	_charged = true
	
	message_field.text = ""
	_base_placeholder = DEFAULT_PLACEHOLDER
	
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
	Tutorial.message_sent.emit(text)
	
	_awaiting_reply = true
	_refresh_busy_state()
	
	var thinking_bubble := chat_bubble_scene.instantiate() as ChatBubble
	thinking_bubble.text = "Thinking..."
	thinking_bubble.bubble_theme = bubble_theme_thinking
	_add_bubble(thinking_bubble)
	thinking_bubble.is_temporary = true
	
	await _send_hint_request(text)

func _reset_chat() -> void:
	http_request.cancel_request()
	_awaiting_reply = false
	
	for child in chat_stack.get_children():
		child.queue_free()
	
	var preface := chat_bubble_scene.instantiate() as ChatBubble
	preface.text = "Hi! I'm your AI Assistant. How can I help you with this level?"
	preface.bubble_theme = bubble_theme_ai
	_add_bubble(preface)
	
	reset_button.disabled = true
	_refresh_busy_state()

## No chat while a program runs, paused included. A paused run is still a run:
## the canvas is locked, the robot is mid-program, and a hint about a program
## half way through executing reads the output log of something unfinished.
## Decided with the panel's "limit the assistant" question; see HintPool for the
## other half of that decision.
func _refresh_busy_state() -> void:
	if in_timeout:
		return
	
	var busy: bool = Interpreter.is_running or _awaiting_reply
	var left := HintPool.available()
	
	submit_button.disabled = busy or left == 0
	# Typing stays open while the pool is empty, so a student can compose the next
	# question while it refills; only sending waits.
	message_field.editable = not busy
	if busy:
		reset_button.disabled = true
	
	submit_button.tooltip_text = "Send (%d of %d questions left)" % [left, HintPool.CAPACITY]
	_update_placeholder(busy, left)

func _update_placeholder(busy: bool, left: int) -> void:
	if Interpreter.is_running:
		message_field.placeholder_text = "Stop the program to ask a question."
	elif left == 0:
		message_field.placeholder_text = "Out of questions for now. Next one in %s." % _clock(HintPool.seconds_to_next())
	elif left <= 3 and not busy:
		message_field.placeholder_text = "%s (%d left)" % [_base_placeholder, left]
	else:
		message_field.placeholder_text = _base_placeholder

func _clock(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]

func prompt_for_question() -> void:
	_base_placeholder = "What did you expect to happen, and what happened instead?"
	_refresh_busy_state()
	if message_field.editable:
		message_field.grab_focus()
#endregion

#region Request
func _send_hint_request(msg: String) -> void:
	var level: Level = Game.level if is_instance_valid(Game.level) else null
	var screenshot := await _get_viewport_jpeg_base64()
	
	var payload := {
		session_id = Game.session_id,
		level_id = level.scene_file_path.get_file().get_basename() if level else "",
		message = msg,
		history = _get_conversation_history(),
		screenshot_jpeg_b64 = screenshot,
		context = {
			instructions = level.description.get_raw() if level else "N/A",
			blocks = _get_available_blocks_doc(),
			workspace = puzzle.canvas.serializer.yaml_serialize(),
			intended_solution = level.intended_solution if level else "N/A",
			last_run = puzzle.describe_last_run(),
			last_run_program = puzzle.last_run_yaml,  # the relay diffs this against workspace
			output_log = "\n".join(Interpreter.output_log.slice(-LOG_LINES)),
			robot = _robot_state(),
		},
	}
	
	_pending_json = JSON.stringify(payload)
	_tried_fallback = false
	
	if OS.is_debug_build():
		var shown := payload.duplicate(true)
		shown.screenshot_jpeg_b64 = "<%d base64 chars, %d bytes: %s>" % [screenshot.length(), _shot_bytes, _shot_note]
		print("-- hint request --\n", JSON.stringify(shown, "  ", false))
	
	_post(api_url)

func _post(url: String) -> void:
	var headers := ["Content-Type: application/json"]
	if not client_token.is_empty():
		headers.append("X-UniCode-Token: " + client_token)
	
	if http_request.request(url, headers, HTTPClient.METHOD_POST, _pending_json) != OK:
		_refund()
		_on_hint_failed("Couldn't start the request. Check %s." % CONFIG_FILE)

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var body_text := body.get_string_from_utf8() if body.size() > 0 else ""
	var data: Variant = JSON.parse_string(body_text)
	var spoke_protocol := typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("status")
	
	if OS.is_debug_build():
		print("-- hint response (HTTP %d, result %d) --\n" % [response_code, result],
			JSON.stringify(data, "  ", false) if spoke_protocol else body_text.left(500))
		# The relay reports how many image bytes it attached for the model. Sent but
		# not attached means the relay rejected it or is running an older main.py.
		if spoke_protocol and _shot_bytes > 0 and (data as Dictionary).has("image_bytes") \
				and int((data as Dictionary).image_bytes) == 0:
			push_warning("AI screenshot: sent %d bytes but the relay attached none. Check the deployed relay's /healthz version." % _shot_bytes)
		elif spoke_protocol and _shot_bytes > 0 and not (data as Dictionary).has("image_bytes"):
			push_warning("AI screenshot: the relay doesn't report image_bytes, so it predates this client. Redeploy ai/main.py.")
	
	# The relay answers in our own shape even when refusing, so anything else means this host
	# never handled the request. That's the only case worth spending on the other host.
	if not spoke_protocol:
		if not _tried_fallback and not fallback_url.is_empty():
			_tried_fallback = true
			await get_tree().process_frame   # let HTTPRequest settle before reusing it
			_post(fallback_url)
			return
		_refund()
		_on_hint_failed("Couldn't reach the hint helper. Check the internet connection.")
		return
	
	var reply := str((data as Dictionary).get("reply", ""))
	match str((data as Dictionary).get("status", "")):
		"ok", "off_topic":
			_charged = false   # spent: the model answered
			_finish_request()
			_add_ai_bubble(reply)
			Tutorial.assistant_replied.emit(reply)
		"blocked":
			_charged = false   # spent: the model saw it, and a blocked message is the student's
			_on_hint_failed(reply if not reply.is_empty() else "Let's keep our chat about this level.")
			_apply_timeout(BLOCKED_TIMEOUT)
		"rate_limited":
			_refund()
			_on_hint_failed(reply if not reply.is_empty() else "Give me a few seconds before the next question.")
			_apply_timeout(RATE_LIMIT_TIMEOUT)
		"unauthorized":
			_refund()
			_on_hint_failed("This copy of UniCode isn't set up to reach the hint helper.")
		_:
			_refund()
			_on_hint_failed(reply if not reply.is_empty() else "The hint helper isn't available right now.")

func _finish_request() -> void:
	_awaiting_reply = false
	_refresh_busy_state()

## Gives the message back to the pool when the model never saw it. Idempotent.
func _refund() -> void:
	if _charged:
		_charged = false
		HintPool.refund()

func _on_hint_failed(text: String) -> void:
	_finish_request()
	_add_ai_bubble(text, true)
	_flag_latest_user_message()   # after the bubble, or _add_bubble would clear the red message
#endregion

#region Context gathering
func _get_conversation_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	
	for child in chat_stack.get_children():
		var bubble := child as ChatBubble
		if bubble == null or bubble.is_temporary or bubble.is_queued_for_deletion():
			continue
		history.append({
			role = "user" if bubble.right_aligned else "model",
			text = bubble.text,
		})
	
	if not history.is_empty():
		history.pop_back()   # the current message travels in `message`
	return history

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
	
	# Presets are filtered on syntax rather than on `toolbox`, because get_preset() sets
	# toolbox = false on every block it hands over, and because the walk also turns up
	# parameter sockets and the Begin block, none of which are authored vocabulary.
	# Scaffolding has no syntax; real blocks do.
	var preset_lines := _format_block_data(
		Game.level.preset.preset_data,
		func(data: BlockData) -> bool: return not data.syntax.is_empty()
	)
	if not preset_lines.is_empty():
		sections.append(
			"\nAlready on the canvas and locked (the student can't copy or delete these):\n"
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

## Where the robot ended up, in the same tile coordinates the level was authored in.
## Assumes the grid is anchored at the level's origin, which every level so far is.
func _robot_state() -> String:
	var robot := get_tree().get_first_node_in_group(&"robot") as Node2D
	if robot == null:
		return "N/A"
	
	const FACING := {
		Vector2.UP: "up", Vector2.DOWN: "down",
		Vector2.LEFT: "left", Vector2.RIGHT: "right",
	}
	var step: float = robot.get(&"step_size") if &"step_size" in robot else 32.0
	
	return "tile %s, facing %s" % [
		Vector2i((robot.global_position / step).floor()),
		FACING.get(robot.get(&"facing_direction"), "?"),
	]

func _get_viewport_jpeg_base64() -> String:
	_shot_bytes = 0
	var img: Image = await _capture_level()
	if img == null:
		push_warning("AI screenshot: nothing captured (%s). The hint goes out without one." % _shot_note)
		return ""
	
	if img.get_width() > SHOT_WIDTH:
		var height := roundi(SHOT_WIDTH * float(img.get_height()) / img.get_width())
		img.resize(SHOT_WIDTH, height, Image.INTERPOLATE_BILINEAR)
	
	var jpeg := img.save_jpg_to_buffer(0.8)
	_shot_bytes = jpeg.size()
	_shot_note += ", %dx%d" % [img.get_width(), img.get_height()]
	return Marshalls.raw_to_base64(jpeg)

## What the student sees in the environment panel, flattened onto an opaque
## background.
##
## The SubViewport is transparent_bg, so its texture is transparent wherever the
## level draws nothing, and in some renderer/driver combinations reading it back
## gives an image that is empty or entirely transparent. Converting straight to
## RGB8 then sends the model a black rectangle, which is indistinguishable from
## sending nothing. So: read the SubViewport; if that comes back unusable, crop
## the panel out of the window instead; either way composite onto a solid colour.
func _capture_level() -> Image:
	if not (is_instance_valid(Game.level) and is_instance_valid(puzzle.level_viewport)):
		_shot_note = "no level or no viewport"
		return null
	
	await RenderingServer.frame_post_draw
	
	var img := puzzle.level_viewport.get_texture().get_image()
	if _usable(img):
		_shot_note = "from the level viewport"
		return _flatten(img)
	
	var why := "empty" if img == null or img.is_empty() else "fully transparent"
	var container := puzzle.level_viewport.get_parent() as Control
	var window := get_viewport().get_texture().get_image()
	if container == null or not _usable(window):
		_shot_note = "level viewport was %s, window capture failed too" % why
		return null
	
	var on_screen := container.get_screen_transform() * Rect2(Vector2.ZERO, container.size)
	var region := Rect2i(on_screen).intersection(Rect2i(Vector2i.ZERO, window.get_size()))
	if region.size.x < 8 or region.size.y < 8:
		_shot_note = "level viewport was %s, environment panel is off screen" % why
		return null
	
	_shot_note = "level viewport was %s, cropped from the window" % why
	return _flatten(window.get_region(region))

func _usable(img: Image) -> bool:
	return img != null and not img.is_empty() \
		and img.get_width() >= 8 and img.get_height() >= 8 \
		and not img.is_invisible()

func _flatten(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var flat := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	flat.fill(SHOT_BACKGROUND)
	flat.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	return flat
#endregion

#region Post-win comment
## A short comment on the student's winning program: a Python connection, a
## real-world parallel, a what-if question, or, when the program is over par, a
## pointer at where it could be tighter. The relay picks which (see
## _summary_angle in ai/main.py). Its own endpoint and prompt: no screenshot, no
## chat history, and it never draws from the HintPool, because it is not a hint.
##
## `placed` and `par` are the game's own numbers; the relay uses them only to
## choose the angle and never repeats them. Returns "" on any failure; the win
## card simply leaves the section out.
func request_summary(program: String, placed := -1, par := -1) -> String:
	if program.is_empty() or not is_instance_valid(Game.level):
		return ""
	
	var level := Game.level
	var body := JSON.stringify({
		session_id = Game.session_id,
		level_id = level.scene_file_path.get_file().get_basename(),
		program = program,
		context = {
			instructions = level.description.get_raw(),
			blocks = _get_available_blocks_doc(),
			placed = placed,
			par = par,
			intended_solution = level.intended_solution,
		},
	})
	
	for url in [_sibling_url(api_url, "summary"), _sibling_url(fallback_url, "summary")]:
		if url.is_empty():
			continue
		var reply: Variant = await _post_summary(url, body)
		if reply != null:
			return reply
	return ""

## null means this host never answered in our shape, so the other is worth a try;
## a String, even an empty one, means the relay answered and that is final.
func _post_summary(url: String, body: String) -> Variant:
	if not is_instance_valid(_summary_http):
		return ""
	var headers := ["Content-Type: application/json"]
	if not client_token.is_empty():
		headers.append("X-UniCode-Token: " + client_token)
	
	_summary_http.cancel_request()
	if _summary_http.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		return null
	
	var outcome: Array = await _summary_http.request_completed
	var raw: PackedByteArray = outcome[3]
	if raw.is_empty():
		return null  # nothing came back at all; JSON.parse_string("") would log an error
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("status"):
		return null
	if OS.is_debug_build():
		print("-- summary response --\n", JSON.stringify(data, "  ", false))
	return str(data.get("reply", "")).strip_edges() if str(data.get("status", "")) == "ok" else ""

## "https://x/api/hint" -> "https://x/api/summary". The cfg can also name one
## outright with summary_url, for a relay that lives somewhere else.
func _sibling_url(url: String, endpoint: String) -> String:
	if url.is_empty():
		return ""
	if url == api_url and not summary_url.is_empty():
		return summary_url
	return url.get_base_dir().path_join(endpoint)
#endregion

#region UI helpers
func _flag_latest_user_message() -> void:
	for idx in range(chat_stack.get_child_count() - 1, -1, -1):
		var bubble := chat_stack.get_child(idx) as ChatBubble
		if bubble == null or bubble.is_queued_for_deletion():
			continue
		if bubble.right_aligned:
			# Stays temporarily on screen as red text, deleted on the next submission
			bubble.is_temporary = true
			bubble.bubble_theme = bubble_theme_error
			break

func _add_ai_bubble(text: String, temporary := false) -> void:
	var bubble := chat_bubble_scene.instantiate() as ChatBubble
	bubble.text = text
	bubble.bubble_theme = bubble_theme_ai if not temporary else bubble_theme_error
	_add_bubble(bubble)
	bubble.is_temporary = temporary

func _add_bubble(bubble: ChatBubble) -> void:
	_clear_temporary()
	
	for node in chat_stack.get_children():
		if not node.is_queued_for_deletion():
			reset_button.disabled = false
			break
	
	chat_stack.add_child(bubble)
	
	var bottom := int(scroll.get_v_scroll_bar().max_value)
	scroll.set_deferred(&"scroll_vertical", bottom)

func _clear_temporary() -> void:
	for node in chat_stack.get_children():
		if node is ChatBubble and (node as ChatBubble).is_temporary:
			node.queue_free()

func _apply_timeout(duration: int) -> void:
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
		_refresh_busy_state()
#endregion
