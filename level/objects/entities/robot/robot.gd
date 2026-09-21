@tool
class_name Robot
extends AnimatableBody2D


const TAGS: Array[StringName] = [&"blocked", &"door", &"puddle"]

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var probe: ShapeCast2D

@export var facing_direction := Vector2.DOWN:
	set(value):
		facing_direction = value
		_update_animation()

var move_duration := 0.2
var move_tween: Tween
var step_size := 32.0


func _ready() -> void:
	_update_animation()
	add_to_group(&"robot")
	
	if not Engine.is_editor_hint():
		Interpreter.running_changed.connect(_on_interpreter_running_changed)
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
	if Interpreter.interrupted:
		return
	
	var velocity := facing_direction * step_size
	if test_move(global_transform, velocity):
		from_this.function.error("Robot: I can't move forward.")
		return
	
	var target := position + velocity
	
	# Capped at the interpreter's pacing so the animation can't outlast the step
	# that started it, and capped below move_duration so slow mode still leaves a
	# still frame for reading the highlighted block instead of gliding for 0.7s.
	var duration := minf(move_duration, Interpreter.current_delay)
	
	cancel_motion()
	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	move_tween.tween_property(self, "position", target, duration)
	
	# step() is the wait; the tween runs inside it rather than after it.
	await Interpreter.step(from_this)
	
	# Invariant: when move() returns, the robot is exactly on the target tile.
	cancel_motion()
	position = target

## Stops any in-flight movement. Without this a tween started before a Stop or a
## hazard keeps writing `position` and overwrites whatever Resettable.reset()
## put there, leaving the robot off-grid.
func cancel_motion() -> void:
	if move_tween != null:
		move_tween.kill()
		move_tween = null

func _on_interpreter_running_changed() -> void:
	if not Interpreter.is_running:
		cancel_motion()

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
	var blocked := false
	for i in hits:
		var collider := probe.get_collider(i)
		if collider == null:
			continue
		
		if collider is SensedArea:
			if (collider as SensedArea).tag == tag:
				return true
		elif not (collider is Area2D):
			blocked = true
		
	
	return blocked if tag == &"blocked" else false
