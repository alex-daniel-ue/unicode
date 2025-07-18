@tool
extends Panel


@warning_ignore("unused_private_class_variable")
@export_tool_button("Re‑generate buttons") var _regen_btn := regenerate_buttons
@warning_ignore("unused_private_class_variable")
@export_tool_button("Update layout now") var _resize_btn := update_layout

@export var reverse := false
@export var icons: Array[Texture2D]

@export var button_container: VBoxContainer
const BUTTON_SIZE := Vector2(50, 50)
var side_button_scene := preload("res://puzzle/ui/side_menu/side_menu_button.tscn")

var viewport_ratio := 1. / 3
const MOVE_DURATION := [0.2, 0.4]  # [show, hide] durations
var shown := true

var contents: Array[Control] = []
var current: Control


func _enter_tree() -> void:
	get_viewport().size_changed.connect(update_layout)

func _ready() -> void:
	_on_child_order_changed()
	
	current = contents[0]
	current.visible = true
	current.size = Vector2(size.x - BUTTON_SIZE.x, 0)
	
	show_menu(false, false)
	regenerate_buttons()
	update_layout()

func _on_child_order_changed() -> void:
	contents.clear()
	for child in get_children():
		if child is Control and child != button_container:
			contents.append(child)
			child.visible = false

func regenerate_buttons() -> void:
	for btn in button_container.get_children():
		btn.queue_free()
	
	for idx in range(len(icons)):
		var icon = icons[idx]
		if not icon:
			continue
		
		var btn = side_button_scene.instantiate() as Button
		btn.custom_minimum_size = BUTTON_SIZE
		btn.icon = icon
		btn.pressed.connect(_on_button_pressed.bind(idx))
		button_container.add_child(btn)

func _on_button_pressed(idx: int) -> void:
	if not (0 <= idx and idx < len(contents)):
		return
	
	if not shown:  # Show menu when it's hidden
		show_menu(true)
	elif current == contents[idx]:  # Hide menu when clicking an icon again
		show_menu(false)
		return
	
	current.visible = false
	
	current = contents[idx]
	current.visible = true
	
	current.size = Vector2(size.x - BUTTON_SIZE.x, 0)
	current.set_anchors_and_offsets_preset(
		PRESET_TOP_RIGHT if reverse else PRESET_TOP_LEFT,
		Control.PRESET_MODE_KEEP_SIZE
	)

func show_menu(do_show: bool, animated := true) -> void:
	if contents.is_empty() or shown == do_show:
		return
	
	var _offset := current.size.x
	if reverse != shown:  # equivalent to reverse ^ shown (XOR operation)
		_offset *= -1
	var target := position + Vector2(_offset, 0)
	
	if animated:
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(self, "position", target, MOVE_DURATION[int(shown)])
	else:
		position = target
	
	shown = do_show

func update_layout() -> void:
	var vp_w = get_viewport_rect().size.x
	size.x = vp_w * viewport_ratio
	
	if current:
		current.size = Vector2(size.x - BUTTON_SIZE.x, 0)
	
	var control_presets: Dictionary[Control, Control.LayoutPreset] = {
		self : PRESET_LEFT_WIDE,
		button_container : PRESET_TOP_RIGHT,
		current : PRESET_TOP_LEFT
	}
	
	if reverse:
		control_presets[self] = PRESET_RIGHT_WIDE
		control_presets[button_container] = PRESET_TOP_LEFT
		control_presets[current] = PRESET_TOP_RIGHT
	
	for control in control_presets:
		control.set_anchors_and_offsets_preset(
			control_presets[control],
			Control.PRESET_MODE_KEEP_SIZE
		)
	
	if not shown:
		position.x += current.size.x if reverse else -current.size.x
