@tool
extends AnimatableBody2D


const TAGS: Array[StringName] = [&"clear", &"blocked", &"door", &"puddle"]

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var probe: ShapeCast2D

@export var facing_direction := Vector2.DOWN:
	set(value):
		facing_direction = value
		_update_animation()

var move_duration := 0.2
var step_size := 32.0


func _ready() -> void:
	_update_animation()
	if not Engine.is_editor_hint():
		if probe:
			probe.enabled = false
			probe.add_exception(self)

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
	await Interpreter.step(from_this)
	if Interpreter.interrupted:
		return
	
	var velocity := facing_direction * step_size
	if test_move(global_transform, velocity):
		from_this.function.error("Robot: I can't move forward.")
		return
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", position + velocity, move_duration)
	
	await tween.finished
	tween.kill()

## text: turn {left/right/back}
func turn(from_this: Block) -> void:
	var args := await from_this.function.eval_args([from_this.function.Argument.STRING])
	if Interpreter.interrupted or args.is_empty():
		return
	
	var turn_dir := args[0] as String
	if turn_dir not in ["left", "right", "back"]:
		from_this.function.error("Robot: Turn direction must be left, right, or back.")
		return
	
	await Interpreter.step(from_this)
	if Interpreter.interrupted:
		return
	
	match turn_dir:
		"left": facing_direction = Vector2(facing_direction.y, -facing_direction.x)
		"right": facing_direction = Vector2(-facing_direction.y, facing_direction.x)
		"back": facing_direction = -facing_direction

## text: ahead is {TAGS}
func ahead_is(from_this: Block) -> bool:
	var args := await from_this.function.eval_args([from_this.function.Argument.STRING])
	if Interpreter.interrupted or args.is_empty():
		return false
	
	var tag := StringName(args[0] as String)
	if tag not in TAGS:
		from_this.function.error('Robot: I don\'t know what "%s" is.' % tag)
		return false
	
	probe.position = facing_direction * step_size
	probe.force_shapecast_update()
	
	var hits := probe.get_collision_count()
	if hits == 0:
		return tag == &"clear"
	
	if tag == &"clear":
		return false
	
	var blocked := false
	for i in hits:
		var collider := probe.get_collider(i)
		if collider == null:
			continue
		
		if collider is SensedArea:
			if (collider as SensedArea).tag == tag:
				return true
		else:
			blocked = true
	
	return blocked if tag == &"blocked" else false
