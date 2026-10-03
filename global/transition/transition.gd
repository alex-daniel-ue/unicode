extends CanvasLayer

## Scene changes fade through the background colour: out, swap, back in.
##
## A plain fade of a ColorRect's opacity, no shader. The diamond shader this
## replaced had its time set to 0 (it was off), and a shader effect is the kind
## of thing that has drawn differently in exports before; a modulate tween draws
## the same everywhere.

@export var cover_time := 0.18
@export var reveal_time := 0.28

@onready var screen := $Screen as ColorRect

var current_tween: Tween


func cover() -> void:
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = true
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(screen, "modulate:a", 1.0, cover_time)

func reveal() -> void:
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(screen, "modulate:a", 0.0, reveal_time)
	await current_tween.finished
	screen.visible = false

func change_scene(scene: Variant) -> void:
	cover()
	await current_tween.finished
	get_tree().scene_changed.connect(reveal, CONNECT_ONE_SHOT)

	if scene is String:
		get_tree().change_scene_to_file(scene)
	elif scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_error("Passed scene isn't String nor PackedScene! %s" % scene)
