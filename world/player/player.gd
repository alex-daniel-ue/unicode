extends CharacterBody2D


enum State { IDLE, WALK }

const SPEED := 125.0

@export var animated_sprite_2d: AnimatedSprite2D

var last_move_dir := Vector2.RIGHT
var current_state := State.IDLE


func _physics_process(_delta: float) -> void:
	var input_direction = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	
	current_state = State.IDLE
	if input_direction != Vector2.ZERO:
		current_state = State.WALK
		if input_direction.x != 0:
			last_move_dir.x = input_direction.x
	
	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			play_idle_animation()
		State.WALK:
			velocity = input_direction * SPEED
			play_walk_animation(input_direction)
	
	move_and_slide()

func play_idle_animation() -> void:
	var anim_to_play := "idle_right" if last_move_dir.x > 0 else "idle_left"
	if animated_sprite_2d.animation != anim_to_play:
		animated_sprite_2d.play(anim_to_play)

func play_walk_animation(direction: Vector2) -> void:
	var anim_to_play := "walk_right"
	
	if direction.x > 0: anim_to_play = "walk_right"
	elif direction.x < 0: anim_to_play = "walk_left"
	elif direction.y > 0: anim_to_play = "walk_left"
	
	if animated_sprite_2d.animation != anim_to_play:
		animated_sprite_2d.play(anim_to_play)
