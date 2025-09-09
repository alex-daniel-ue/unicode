class_name BlockVisualComponent
extends BlockBaseComponent


const COLOR_CHANGE_MULT := 10.0
const ERROR_SPD_MULT := 4.0
const ERROR_DURATION := 2.0

@export var highlight_color := Color("#ffe350")
@export var error_color := Color("ff8080")
@export var color_affected: Array[Control]

var target_color := Color.WHITE

var error_timer: Timer
var error_t := 2.0
var erroring := false:
	set = set_error


func _ready() -> void:
	error_timer = Timer.new()
	error_timer.one_shot = true
	error_timer.timeout.connect(set_error.bind(false))
	add_child(error_timer)

func _update(delta: float) -> void:
		var final_target := target_color
		
		if erroring:
			error_t += delta * ERROR_SPD_MULT
			var t := pingpong(error_t, 1.0)
			final_target = error_color.lerp(Color.WHITE, t)
		
		for affected in color_affected:
			affected.self_modulate = affected.self_modulate.lerp(final_target, delta * COLOR_CHANGE_MULT)

func highlight() -> void:
	target_color = highlight_color

func reset() -> void:
	target_color = Color.WHITE

func set_error(to: bool) -> void:
	erroring = to
	if erroring:
		error_t = 0.0

func start_error_timer() -> void:
	error_timer.start(ERROR_DURATION)
