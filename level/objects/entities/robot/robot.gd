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
	var args: Array = await from_this.function.evaluate_args(1)
	if Puzzle.has_errored:
		return
	
	var err_message := Core.validate_type(args[0], [TYPE_STRING], 0)
	if not err_message.is_empty():
		from_this.function.error(err_message)
		return
	
	var direction := args[0] as String
	if not DIR_TO_VEC.has(direction):
		from_this.function.error("Direction must be up, down, left, or right.")
		return
	
	from_this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	
	var velocity := DIR_TO_VEC[direction] * step_size
	if not test_move(global_transform, velocity):
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "position", position + velocity, move_duration)
		await tween.finished
	
	from_this.visual.reset()
