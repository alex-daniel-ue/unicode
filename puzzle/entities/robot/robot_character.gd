@tool
extends StaticBody2D


const dir_to_vec: Dictionary[String, Vector2] = {
	up = Vector2.UP,
	down = Vector2.DOWN,
	left = Vector2.LEFT,
	right = Vector2.RIGHT,
}

@warning_ignore("unused_private_class_variable")
@export_tool_button("Save properties as initial") var _001 := save_initial
@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var area: Area2D

@export_storage var initial_transform: Transform2D

var move_duration := 0.15
var step := 32


func save_initial() -> void:
	initial_transform = transform

func reset() -> void:
	transform = initial_transform

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

## text: PICK UP
func pick_up(from_this: Block) -> Utils.Result:
	if is_on_litter(from_this).data:
		var litter := _get_overlapping_litter()
		if litter != null:
			litter.pick_up()
	
	return Utils.Result.success()

## text: IS ON LITTER
func is_on_litter(_from_this: Block) -> Utils.Result:
	if area.has_overlapping_areas():
		if _get_overlapping_litter() != null:
			return Utils.Result.success(true)
	
	return Utils.Result.success(false)

func _get_overlapping_litter() -> Litter:
	for overlapping_area in area.get_overlapping_areas():
		if overlapping_area is Litter:
			return overlapping_area
	return null
