extends Node


const PUZZLE_SCENE := preload("res://puzzle/puzzle.tscn")

var pending_level: PackedScene
var completed_levels: PackedStringArray
var last_world_pos: Vector2
var level_star_counts: Dictionary = {}


func update_level_stars(level_path: String, stars: int) -> void:
	if not level_star_counts.has(level_path):
		level_star_counts[level_path] = stars
	else:
		level_star_counts[level_path] = max(stars, level_star_counts[level_path])
	
	print("Star count for '%s' updated to: %s" % [level_path.get_file(), level_star_counts[level_path]])

func start_puzzle() -> void:
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_packed(PUZZLE_SCENE)
	
	await get_tree().scene_changed
	pending_level = null

func save_to_disk() -> void:
	pass

func load_from_disk(path: String) -> void:
	pass

func sleep(seconds: float) -> void:
	if seconds <= 0:
		await get_tree().process_frame
		return
	
	await get_tree().create_timer(seconds).timeout
