extends CanvasLayer
## Scene changes fade through the background colour: out, swap, back in.
##
## A tween of a ColorRect's opacity rather than a shader, since a modulate tween
## draws the same on every renderer and in every export.

@export var cover_time := 0.18
@export var reveal_time := 0.28

var _tween: Tween

@onready var _screen := $Screen as ColorRect


## Fades out, changes to `scene` (a path or a PackedScene) and fades back in.
func change_scene(scene: Variant) -> void:
	_cover()
	await _tween.finished
	get_tree().scene_changed.connect(_reveal, CONNECT_ONE_SHOT)

	if scene is String:
		get_tree().change_scene_to_file(scene)
	elif scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_error("Passed scene isn't String nor PackedScene! %s" % scene)


func _cover() -> void:
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_screen, "modulate:a", 1.0, cover_time)


func _reveal() -> void:
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_screen, "modulate:a", 0.0, reveal_time)
	await _tween.finished
	_screen.visible = false
