@tool
extends HBoxContainer


const BUTTON_SIZE := Vector2(50, 50)

@export_tool_button("Cycle through panels") var __1 := func() -> void:
	current_panel_idx += 1
	current_panel_idx %= count_panels()
	set_panel(current_panel_idx)
@export var current_panel_idx := 0
@export var panel_icons: Array[Texture2D]
@export var panel_ratio := 1. / 4

var main_theme := preload("res://themes/main.tres")
var current_panel: Panel
var is_panel_hidden := false

@onready var button_container := $MarginContainer/ButtonContainer
@onready var hide_button := $MarginContainer/ButtonContainer/HideButton


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	hide_button.custom_minimum_size = BUTTON_SIZE

func _process(_delta: float) -> void:
	if not current_panel:
		return
	
	size.x = 0
	current_panel.size.x = 0
	current_panel.custom_minimum_size.x = get_viewport_rect().size.x * panel_ratio

func _get_configuration_warnings() -> PackedStringArray:
	if count_panels() == 0:
		return ["SideMenu requires at least one Panel to display."]
	return []

func set_panel(idx: int) -> void:
	# Do nothing when panel is hidden
	if is_panel_hidden:
		return
	
	var child_idx := 0
	for child in get_children():
		# Skip over non-Panels
		if child is Panel:
			child.visible = child_idx == idx
			if child.visible:
				current_panel = child
			child_idx += 1

func count_panels() -> int:
	var count := 0
	for child in get_children():
		if child is Panel:
			count += 1
	return count

func hide_menu(do_anim := true) -> void:
	var duration := 0.2 if is_panel_hidden else 0.4
	
	var offset := position
	offset.x += current_panel.size.x
	if not is_panel_hidden:
		offset.x *= -1
	
	if do_anim:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "position", offset, duration)
		tween.play()
	else:
		position = offset
	
	is_panel_hidden = not is_panel_hidden

func update_buttons() -> void:
	for child in button_container.get_children():
		if child != hide_button:
			if child.get_parent() == self:
				remove_child(child)
			child.queue_free()
	
	var idx := 0
	for icon in panel_icons:
		var button := Button.new()
		button_container.add_child(button)
		
		button.custom_minimum_size = BUTTON_SIZE
		button.icon = icon
		button.expand_icon = true
		button.theme = main_theme
		button.theme_type_variation = &"SideMenuIcon"
		button.pressed.connect(set_panel.bind(idx))
		
		idx += 1

func _on_child_order_changed() -> void:
	set_panel(current_panel_idx)
	update_buttons.call_deferred()
	move_child.call_deferred($MarginContainer, get_child_count())
