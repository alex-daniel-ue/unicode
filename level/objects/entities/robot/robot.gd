@tool
extends AnimatableBody2D


const DIR_TO_VEC: Dictionary[String, Vector2] = {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
}

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var move_duration := 0.2
var step_size := 32.0


## text: move {up/down/left/right}
func move(from_this: Block) -> void:
	var args := await from_this.function.eval_args([from_this.function.Argument.STRING])
	if Interpreter.interrupted:
		return
	
	var direction := args[0] as String
	if not DIR_TO_VEC.has(direction):
		from_this.function.error("Robot: Direction must be up, down, left, or right.")
		return
	
	await from_this.visual.pulse()
	if Interpreter.interrupted:
		return
	
	var velocity := DIR_TO_VEC[direction] * step_size
	if test_move(global_transform, velocity):
		from_this.function.error("Robot: I can't move %s!" % direction)
		return
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", position + velocity, move_duration)
	
	await tween.finished
