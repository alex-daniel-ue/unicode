extends Node

signal progress_updated


var level_stars: PackedInt32Array = PackedInt32Array()
var level_index_map: Dictionary[String, int] = {
	"it_0a": 0, "it_0b": 1, "it_1": 2, "it_2": 3, "it_3": 4,
	"it_4": 5, "it_5": 6, "it_6": 7, "it_7": 8, "it_8": 9,
	"lt_1": 10, "lt_2": 11, "lt_3": 12, "lt_4": 13, "lt_5": 14,
	"lt_6": 15, "lt_7": 16, "lt_8": 17, "lt_9": 18, "lt_10": 19
}


func _ready() -> void:
	level_stars.resize(ProgressCode.LEVELS)
	level_stars.fill(0)

func get_code() -> String:
	return ProgressCode.encode(level_stars)

func apply_code(code: String) -> bool:
	if not ProgressCode.is_valid(code):
		return false
	var decoded := ProgressCode.decode(code)
	if decoded.is_empty():
		return false
	
	# Keep the higher score for each level
	for i in range(mini(level_stars.size(), decoded.size())):
		level_stars[i] = maxi(level_stars[i], decoded[i])
	
	progress_updated.emit()
	return true

func record_completion(level_id: String, stars: int) -> void:
	var key := level_id.to_lower()
	if level_index_map.has(key):
		var idx: int = level_index_map[key]
		level_stars[idx] = maxi(level_stars[idx], clampi(stars, 1, 3))
		progress_updated.emit()

func get_stars(level_id: String) -> int:
	var key := level_id.to_lower()
	if level_index_map.has(key):
		return level_stars[level_index_map[key]]
	return 0
