extends CanvasLayer


const SHADER_PARAM_PROGRESS := "shader_parameter/progress"

@export var transition_time := 0.6

@onready var screen := $DiamondScreen as ColorRect

var current_tween: Tween


func cover() -> void:
	screen.visible = true
	
	current_tween = create_tween()
	current_tween.set_parallel()
	
	current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(screen.material, SHADER_PARAM_PROGRESS, 1, transition_time).from(0)

func reveal() -> void:
	current_tween = create_tween()
	current_tween.set_parallel()
	
	current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(screen.material, SHADER_PARAM_PROGRESS, 2, transition_time).from(1)
	
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
