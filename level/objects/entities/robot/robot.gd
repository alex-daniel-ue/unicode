@tool
extends AnimatableBody2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

@export var facing_direction := Vector2.DOWN:
	set(value):
		facing_direction = value
		_update_animation()

var move_duration := 0.2
var step_size := 32.0


func _ready() -> void:
	_update_animation()

func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	
	match facing_direction:
		Vector2.DOWN: sprite.play("idle_backward")
		Vector2.UP: sprite.play("idle_forward")
		Vector2.LEFT: sprite.play("idle_left")
		Vector2.RIGHT: sprite.play("idle_right")

## text: move forward
func move(from_this: Block) -> void:
	await from_this.visual.pulse()
	if Interpreter.interrupted:
		return
	
	var velocity := facing_direction * step_size
	if test_move(global_transform, velocity):
		from_this.function.error("Robot: I can't move forward!")
		return
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", position + velocity, move_duration)
	
	await tween.finished

## text: turn {left/right}
func turn(from_this: Block) -> void:
	var args := await from_this.function.eval_args([from_this.function.Argument.STRING])
	if Interpreter.interrupted:
		return
	
	var turn_dir := args[0] as String
	if turn_dir not in ["left", "right"]:
		from_this.function.error("Robot: Turn direction must be 'left' or 'right'.")
		return
	
	await from_this.visual.pulse()
	if Interpreter.interrupted:
		return
	
	if turn_dir == "left":
		facing_direction = Vector2(facing_direction.y, -facing_direction.x)
	else:
		facing_direction = Vector2(-facing_direction.y, facing_direction.x)
