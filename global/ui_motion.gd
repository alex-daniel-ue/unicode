extends Node

## One place for how the interface moves, so every screen moves the same way:
## popups and cards pop in, things that appear fade in, grids of buttons arrive
## one after another, and every button answers the pointer.
##
## Two parts. The helpers below (pop_in, fade_in, stagger_in) are called by
## screens that show something. The hooks are automatic: every button that
## enters the tree grows a little under the pointer and dips when pressed, and
## every popup's content pops in as it opens, without each scene wiring it.
## Buttons inside blocks are left alone; a block on the canvas is not a menu.

const POP_TIME := 0.2
const FADE_TIME := 0.2
const STAGGER := 0.035
const HOVER_SCALE := Vector2(1.05, 1.05)
const PRESS_SCALE := Vector2(0.95, 0.95)
const HOVER_TIME := 0.1


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


#region Helpers
## Scales `control` up from a little smaller while it fades in, overshooting a
## touch, around its centre. For cards and popups.
func pop_in(control: Control, duration := POP_TIME) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	# Laid out first, so the centre it scales around is the real one.
	await get_tree().process_frame
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(0.94, 0.94)
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8)

func fade_in(item: CanvasItem, duration := FADE_TIME, delay := 0.0) -> void:
	if not is_instance_valid(item):
		return
	item.modulate.a = 0.0
	var tween := item.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(item, "modulate:a", 1.0, duration)

## Each of `items` fades and rises in a little after the one before it.
func stagger_in(items: Array, step := STAGGER) -> void:
	for i in items.size():
		var item := items[i] as Control
		if item == null:
			continue
		item.modulate.a = 0.0
		var tween := item.create_tween()
		tween.tween_interval(i * step)
		tween.tween_property(item, "modulate:a", 1.0, FADE_TIME)
#endregion


#region Automatic hooks
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_juice_button.call_deferred(node)
	elif node is Popup:
		(node as Popup).about_to_popup.connect(_on_popup.bind(node))

func _juice_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta(&"no_juice") or _inside_block(button):
		return
	button.mouse_entered.connect(_scale_button.bind(button, HOVER_SCALE))
	button.mouse_exited.connect(_scale_button.bind(button, Vector2.ONE))
	button.button_down.connect(_scale_button.bind(button, PRESS_SCALE))
	button.button_up.connect(func() -> void:
		_scale_button(button, HOVER_SCALE if button.is_hovered() else Vector2.ONE))

func _scale_button(button: BaseButton, to: Vector2) -> void:
	if not is_instance_valid(button):
		return
	if button.disabled and to != Vector2.ONE:
		return
	button.pivot_offset = button.size / 2.0
	var old: Tween = button.get_meta(&"juice_tween", null)
	if old != null and old.is_valid():
		old.kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale", to, HOVER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta(&"juice_tween", tween)

func _on_popup(popup: Popup) -> void:
	for child in popup.get_children():
		if child is Control:
			pop_in(child as Control)
			return

func _inside_block(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is Block:
			return true
		parent = parent.get_parent()
	return false
#endregion
