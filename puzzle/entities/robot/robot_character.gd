extends StaticBody2D


const dir_to_vec: Dictionary[String, Vector2] = {
	up = Vector2.UP,
	down = Vector2.DOWN,
	left = Vector2.LEFT,
	right = Vector2.RIGHT,
}

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var move_duration := 0.15
var step := 32


## text: MOVE [up/down/left/right]
func move(from_this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, from_this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	var direction := args[0] as String
	var velocity := dir_to_vec[direction] * step
	if not test_move(global_transform, velocity):
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "position", position + velocity, move_duration)
		await tween.finished
	
	return Utils.Result.success()

## text: CAN MOVE [up/down/left/right]
func can_move(from_this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, from_this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	var direction := args[0] as String
	var velocity := dir_to_vec[direction] * step
	
	return Utils.Result.success(not test_move(global_transform, velocity))
