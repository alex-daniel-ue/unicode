extends Node

## Star progress. Authoritative in memory, mirrored to user://progress.cfg, and
## portable as a ProgressCode.
##
## Three changes from the previous version, all of them deployment concerns:
##
##   1. It persists. Nothing wrote to disk before, so closing the game lost
##      everything unless the student had copied a code off the win screen.
##   2. Level ids come from the LevelCatalog rather than a hardcoded dictionary,
##      so "lt_1..lt_10" and the level-select module list can no longer drift
##      apart from each other or from the design doc's names.
##   3. An unknown level id is reported instead of silently ignored. A typo in a
##      scene name used to mean a solved level recorded nothing, with no sign
##      anything had gone wrong.

signal progress_updated

const SAVE_PATH := "user://progress.cfg"
const CATALOG_PATH := "res://global/utils/level_catalog.tres"

var catalog: LevelCatalog
var level_stars: PackedInt32Array = PackedInt32Array()

## True when this machine had no save file at startup. The tutorial prompt uses
## this as its "first run" test.
var is_fresh := true

var _disk_available := true


func _ready() -> void:
	level_stars.resize(ProgressCode.LEVELS)
	level_stars.fill(0)

	catalog = load(CATALOG_PATH) as LevelCatalog
	if catalog == null:
		push_error("Progress: no LevelCatalog at %s. Level select and stars will be empty." % CATALOG_PATH)
	else:
		for problem in catalog.problems():
			push_error("LevelCatalog: " + problem)

	_load_from_disk()

#region Public API
func get_code() -> String:
	return ProgressCode.encode(level_stars)


## Merges a typed code in, keeping the better of the two per level. False when
## the code is malformed, so the caller can say so rather than appearing to work.
func apply_code(code: String) -> bool:
	var decoded := ProgressCode.decode(code)
	if decoded.is_empty():
		return false

	var changed := false
	for i in mini(level_stars.size(), decoded.size()):
		var merged := maxi(level_stars[i], decoded[i])
		if merged != level_stars[i]:
			level_stars[i] = merged
			changed = true

	if changed:
		_save_to_disk()
	progress_updated.emit()
	return true


## Records a win. Stars are clamped to 1..3 because completing a level is itself
## worth one star (§7: the first star is the completion marker).
func record_completion(level_id: StringName, stars: int) -> void:
	var slot := slot_of(level_id)
	if slot < 0:
		# A level that deliberately owns no progress slot (the tutorial) is
		# finished quietly. An id the catalog has never heard of is a wiring
		# mistake and has to be loud, because the symptom is a solved level
		# that records nothing.
		var known: bool = catalog != null and catalog.entry_of(level_id) != null
		if not known:
			push_error(
				"Progress: level id '%s' is not in the LevelCatalog, so this completion was not recorded. "
				% level_id + "Add a LevelEntry for it."
			)
		return

	var earned := clampi(stars, 1, 3)
	if earned <= level_stars[slot]:
		progress_updated.emit()
		return

	level_stars[slot] = earned
	_save_to_disk()
	progress_updated.emit()


func get_stars(level_id: StringName) -> int:
	var slot := slot_of(level_id)
	return level_stars[slot] if slot >= 0 else 0


func is_complete(level_id: StringName) -> bool:
	return get_stars(level_id) > 0


func slot_of(level_id: StringName) -> int:
	return catalog.slot_of(level_id) if catalog != null else -1


func total_stars() -> int:
	return ProgressCode.score(level_stars)


## Index of the furthest scored level with at least one star, or -1 for a fresh
## save. Level select uses this for sequential unlocking.
func furthest_slot() -> int:
	var furthest := -1
	for i in level_stars.size():
		if level_stars[i] > 0:
			furthest = i
	return furthest


func reset() -> void:
	level_stars.fill(0)
	_save_to_disk()
	progress_updated.emit()
#endregion

#region Persistence
## Best-effort. A lab PC that restores itself on reboot, or a roaming profile
## with user:// read-only, must not take the game down with it. The progress
## code is the real answer on those machines; this is the convenience on top.
func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("Progress: could not read %s (error %d). Starting fresh." % [SAVE_PATH, err])
		return

	is_fresh = false

	# Stored as a code rather than as raw ints so the file is checksummed by the
	# same routine as a typed code, and a half-written file is rejected instead
	# of loading as garbage.
	var stored_code := str(cfg.get_value("progress", "code", ""))
	var decoded := ProgressCode.decode(stored_code)
	if decoded.is_empty():
		if not stored_code.is_empty():
			push_warning("Progress: %s holds an unreadable code. Ignoring it." % SAVE_PATH)
		return

	for i in mini(level_stars.size(), decoded.size()):
		level_stars[i] = maxi(level_stars[i], decoded[i])


func _save_to_disk() -> void:
	if not _disk_available:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("progress", "code", get_code())
	cfg.set_value("progress", "stars", total_stars())
	cfg.set_value("progress", "saved_at", Time.get_datetime_string_from_system(true))

	var err := cfg.save(SAVE_PATH)
	if err != OK:
		# Say it once. A machine that cannot write user:// will fail every save,
		# and forty identical warnings per session hide everything else.
		_disk_available = false
		push_warning(
			"Progress: cannot write %s (error %d). Progress will survive this session only, "
			% [SAVE_PATH, err] + "students on this machine must copy their progress code."
		)
#endregion
