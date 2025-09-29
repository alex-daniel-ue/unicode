extends Node


const PUZZLE_SCENE := preload("res://puzzle/puzzle.tscn")
const WORLD_SCENE := preload("res://world/rooms/computer_lab.tscn")

var pending_level: PackedScene
var completed_levels: PackedStringArray
var last_world_pos: Vector2


func start_puzzle() -> void:
	get_tree().change_scene_to_packed(PUZZLE_SCENE)
	await get_tree().scene_changed
	pending_level = null

func return_to_world() -> void:
	get_tree().change_scene_to_packed(WORLD_SCENE)

func save_to_disk() -> void:
	pass

func load_from_disk(path: String) -> void:
	pass

func sleep(seconds: float) -> void:
	if seconds <= 0:
		await get_tree().process_frame
		return
	
	await get_tree().create_timer(seconds).timeout
