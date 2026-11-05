@tool
class_name Robot
extends AnimatableBody2D
## The robot a program drives. Its blocks (move.tres, move_n.tres, turn.tres,
## ahead_is.tres) call the methods here with the calling block last.
##
## Every bit of motion that isn't the move itself is on the sprite, never on the
## body: goals, physics and Resettable read the body's position and facing, so
## those stay exact, and the sprite always settles back to its rest pose.

const TAGS: Array[StringName] = [&"blocked", &"destination", &"puddle"]
## How high the sprite hops on a turn, and on a turn all the way around.
const TURN_HOP := 7.0
const AROUND_HOP := 11.0
## The little bob of a step.
const STEP_BOB := 2.5
## The longest a turn's hop takes; faster speeds shorten it with the step.
const TURN_TIME := 0.26
const MOVE_DURATION := 0.2

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var probe: ShapeCast2D
@export var facing_direction := Vector2.DOWN:
	set(value):
		facing_direction = value
		_update_animation()

## One tile, in pixels.
var step_size := 32.0

var _move_tween: Tween
## The sprite's pose at rest.
var _rest_position: Vector2
var _rest_scale: Vector2
var _juice: Tween


func _ready() -> void:
	_update_animation()
	add_to_group(&"robot")
	if is_instance_valid(sprite):
		_rest_position = sprite.position
		_rest_scale = sprite.scale

	if not Engine.is_editor_hint():
		Interpreter.running_changed.connect(_on_interpreter_running_changed)
		if probe:
			probe.enabled = false
			probe.add_exception(self)
		var level := _level()
		if level != null:
			level.completed.connect(_celebrate)
			level.failed.connect(_shake_head.unbind(1))


## step forward
func move(from_this: Block) -> void:
	if Interpreter.interrupted:
		return

	var velocity := facing_direction * step_size
	if test_move(global_transform, velocity):
		_bump()
		from_this.function.error("Robot: I can't step forward.")
		return

	var target := position + velocity
	# Capped at the interpreter's pacing so the animation can't outlast the step
	# that started it, and capped below MOVE_DURATION so slow mode still leaves a
	# still frame for reading the highlighted block instead of gliding for 0.7 s.
	var duration := minf(MOVE_DURATION, Interpreter.current_delay)

	cancel_motion()
	_move_tween = create_tween()
	_move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_property(self, "position", target, duration)
	_hop(STEP_BOB, duration)

	# step() is the wait; the tween runs inside it rather than after it.
	await Interpreter.step(from_this)

	# When move() returns, the robot is exactly on the target tile.
	cancel_motion()
	position = target


## step forward {count} times
##
## Arrays' move. Repetition isn't the lesson there, and a list's values need a
## slot to plug into: `step forward (item i of route) times`. It is n single
## steps, each checked for a wall and paced like `step forward`, so a wrong count
## walks and bumps where the student can see it.
func move_steps(from_this: Block) -> void:
	var args := await from_this.function.eval_args([from_this.function.Argument.VARIANT])
	if Interpreter.interrupted or args.is_empty():
		return

	var times: Variant = from_this.function.unwrap(args[0])
	if Interpreter.interrupted:
		return

	if typeof(times) == TYPE_FLOAT:
		from_this.function.error("Robot: I can only step forward a whole number of times, not %s. Use // to divide without a decimal." % times)
		return
	if typeof(times) != TYPE_INT:
		from_this.function.error("Robot: I can only step forward a whole number of times, but I got %s." % Core.to_python_repr(times))
		return
	if times < 0:
		from_this.function.error("Robot: I can't step forward %d times. I only go forward." % times)
		return

	if times == 0:
		await Interpreter.step(from_this)
		return
	for i in times:
		await move(from_this)
		if Interpreter.interrupted:
			return


## turn {left/right/around}
func turn(from_this: Block) -> void:
	var args := await from_this.function.eval_args([from_this.function.Argument.STRING])
	if Interpreter.interrupted or args.is_empty():
		return

	var turn_dir := args[0] as String
	if turn_dir not in ["left", "right", "around"]:
		from_this.function.error("Robot: Turn direction must be left, right, or around.")
		return

	var turned := facing_direction
	match turn_dir:
		"left": turned = Vector2(facing_direction.y, -facing_direction.x)
		"right": turned = Vector2(-facing_direction.y, facing_direction.x)
		"around": turned = -facing_direction

	# A hop in place, turning at the top of it, so the turn is something seen
	# happen rather than a frame that changes.
	_hop(AROUND_HOP if turn_dir == "around" else TURN_HOP, minf(TURN_TIME, Interpreter.current_delay),
			func() -> void: facing_direction = turned)
	await Interpreter.step(from_this)
	if Interpreter.interrupted:
		return
	facing_direction = turned


## ahead is {TAGS}
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

	var blocked := false
	var found := false
	for i in probe.get_collision_count():
		var collider := probe.get_collider(i)
		if collider == null:
			continue
		if collider is SensedArea:
			if (collider as SensedArea).tag == tag:
				found = true
		elif not (collider is Area2D):
			blocked = true

	if tag == &"blocked":
		found = found or blocked
	_scan(found)
	return found


## Stops any movement under way. A tween left running after a Stop or a hazard
## keeps writing `position` and overwrites whatever Resettable.reset() put
## there, leaving the robot off the grid.
func cancel_motion() -> void:
	if _move_tween != null:
		_move_tween.kill()
		_move_tween = null


func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	match facing_direction:
		Vector2.DOWN: sprite.play("idle_backward")
		Vector2.UP: sprite.play("idle_forward")
		Vector2.LEFT: sprite.play("idle_left")
		Vector2.RIGHT: sprite.play("idle_right")


func _level() -> Level:
	var node: Node = get_parent()
	while node != null and not node is Level:
		node = node.get_parent()
	return node as Level


## Lights the tile that ahead_is() just looked at (TileScan): yellow while it
## looks, then the answer's colour. Behind the robot's own sprite, whose head
## reaches up into the tile above.
func _scan(found: bool) -> void:
	var scan := TileScan.new()
	scan.tile = step_size
	scan.found = found
	scan.position = facing_direction * step_size
	scan.rotation = facing_direction.angle()
	scan.show_behind_parent = true
	add_child(scan)
	# Inside one step: every block waits a step before it acts, so the scan is
	# over before anything moves the robot (it's the robot's child, and would
	# slide along with it).
	scan.play(clampf(Interpreter.current_delay * 0.85, 0.02, 0.6))


func _on_interpreter_running_changed() -> void:
	if not Interpreter.is_running:
		cancel_motion()
	else:
		_settle()


#region The sprite's motion
## Puts the sprite back at rest, stopping whatever it was doing.
func _settle() -> void:
	if _juice != null:
		_juice.kill()
		_juice = null
	if is_instance_valid(sprite) and _rest_scale != Vector2.ZERO:
		sprite.position = _rest_position
		sprite.scale = _rest_scale
		sprite.rotation = 0.0


func _fresh_juice() -> Tween:
	_settle()
	_juice = create_tween()
	return _juice


## Up `height` pixels and down again in `duration`, stretching on the way up and
## squashing a little on landing. `at_top` runs at the top of the hop.
func _hop(height: float, duration: float, at_top := Callable()) -> void:
	if not is_instance_valid(sprite) or duration <= 0.0:
		if at_top.is_valid():
			at_top.call()
		return
	var tween := _fresh_juice()
	var up := _rest_position - Vector2(0, height)
	tween.tween_property(sprite, "position", up, duration * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", _rest_scale * Vector2(0.94, 1.07), duration * 0.42)
	if at_top.is_valid():
		tween.tween_callback(at_top)
	tween.tween_property(sprite, "position", _rest_position, duration * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", _rest_scale, duration * 0.38)
	tween.tween_property(sprite, "scale", _rest_scale * Vector2(1.08, 0.92), duration * 0.08)
	tween.tween_property(sprite, "scale", _rest_scale, duration * 0.12)


## Leans into the wall and rocks back: the move that couldn't happen.
func _bump() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := _fresh_juice()
	var lean := _rest_position + facing_direction * 5.0
	tween.tween_property(sprite, "position", lean, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", _rest_position, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", 0.12 * (1.0 if facing_direction.x >= 0.0 else -1.0), 0.06)
	tween.tween_property(sprite, "rotation", 0.0, 0.12)


## Two happy hops when the level is solved.
func _celebrate() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := _fresh_juice()
	for height in [12.0, 8.0]:
		tween.tween_property(sprite, "position", _rest_position - Vector2(0, height), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position", _rest_position, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "scale", _rest_scale * Vector2(1.1, 0.9), 0.05)
		tween.tween_property(sprite, "scale", _rest_scale, 0.08)


## A small shake of the head when a room isn't solved.
func _shake_head() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := _fresh_juice()
	for angle in [0.14, -0.14, 0.09, -0.06, 0.0]:
		tween.tween_property(sprite, "rotation", angle, 0.06)
#endregion
