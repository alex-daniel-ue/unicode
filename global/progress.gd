extends Node
## Star progress: held in memory, saved to user://progress.cfg, and portable as
## a ProgressCode.
##
## Level ids and slots come from the LevelCatalog, so level select, the stars
## and the code all read one list. An id the catalog doesn't know is reported,
## because the only other sign of a misnamed level is a win that records nothing.

signal progress_updated

const SAVE_PATH := "user://progress.cfg"
const CATALOG_PATH := "res://global/utils/level_catalog.tres"
## The levels a version 1 code holds, in its slot order. Arrays 1 and 2 had no
## slot then, and ar-9 (Tidy up) has since been cut, so its stars drop out.
const V1_SLOTS: Array[StringName] = [
	&"it-1", &"it-2", &"it-3", &"it-4", &"it-5", &"it-6", &"it-7", &"it-8", &"it-9", &"it-10",
	&"ar-3", &"ar-4", &"ar-5", &"ar-6", &"ar-7", &"ar-8", &"ar-9", &"ar-10", &"ar-11",
]

var catalog: LevelCatalog
var level_stars: PackedInt32Array = PackedInt32Array()
## Stars for the levels that own no progress slot (the Tutorial module), by
## level id. Kept in the save file only: they are a reward on the level grid,
## not part of the code or of the study's data.
var practice_stars: Dictionary[StringName, int] = {}

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


func get_code() -> String:
	return ProgressCode.encode(level_stars)


## Merges a typed code in, keeping the better of the two per level. False when
## the code is malformed, so the caller can say so rather than appearing to work.
func apply_code(code: String) -> bool:
	var decoded := _decode(code)
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


## Records a win. Stars are clamped to 1..3: completing a level is itself worth
## the first star.
func record_completion(level_id: StringName, stars: int) -> void:
	var earned := clampi(stars, 1, 3)
	var slot := slot_of(level_id)
	if slot < 0:
		# A level that owns no progress slot (a tutorial) keeps its stars in the
		# save file only. An id the catalog has never heard of is a wiring
		# mistake, and has to be loud.
		if catalog == null or catalog.entry_of(level_id) == null:
			push_error(
				"Progress: level id '%s' is not in the LevelCatalog, so this completion was not recorded. "
				% level_id + "Add a LevelEntry for it."
			)
			return
		if earned > practice_stars.get(level_id, 0):
			practice_stars[level_id] = earned
			_save_to_disk()
		progress_updated.emit()
		return

	if earned > level_stars[slot]:
		level_stars[slot] = earned
		_save_to_disk()
	progress_updated.emit()


func get_stars(level_id: StringName) -> int:
	var slot := slot_of(level_id)
	return level_stars[slot] if slot >= 0 else practice_stars.get(level_id, 0)


func is_complete(level_id: StringName) -> bool:
	return get_stars(level_id) > 0


func slot_of(level_id: StringName) -> int:
	return catalog.slot_of(level_id) if catalog != null else -1


func total_stars() -> int:
	return ProgressCode.score(level_stars)


## Whether a level is open under sequential unlock. Each module is its own
## sequence, in the order the grid shows it, practice levels included: a level
## opens once the furthest solved level in its module is no more than
## `unlock_lookahead` places behind it. The first level of a module is always
## open; whether the module shows at all is its release gate.
func is_unlocked(level_id: StringName) -> bool:
	if catalog == null or not catalog.sequential_unlock:
		return true
	var module := catalog.module_of(level_id)
	if module == null:
		return true

	var place := -1
	var furthest_solved := -1
	var position := 0
	for entry in module.levels:
		# Skipped, not counted: a level nobody can play must not hold the rest shut.
		if entry == null or entry.retired or entry.scene == null:
			continue
		if entry.id == level_id:
			place = position
		if is_complete(entry.id):
			furthest_solved = position
		position += 1
	return place <= furthest_solved + catalog.unlock_lookahead


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

	# Stored as a code rather than as raw ints so the file is checksummed by the
	# same routine as a typed code, and a half-written file is rejected instead
	# of loading as garbage.
	var stored_code := str(cfg.get_value("progress", "code", ""))
	var decoded := _decode(stored_code)
	if decoded.is_empty():
		if not stored_code.is_empty():
			push_warning("Progress: %s holds an unreadable code. Ignoring it." % SAVE_PATH)
		return

	for i in mini(level_stars.size(), decoded.size()):
		level_stars[i] = maxi(level_stars[i], decoded[i])

	for key in (cfg.get_section_keys("practice") if cfg.has_section("practice") else PackedStringArray()):
		var id := StringName(key)
		var stars := clampi(int(cfg.get_value("practice", key, 0)), 0, 3)
		var slot := slot_of(id)
		# A practice level that has since become a scored one keeps its stars,
		# in its slot now. One that left the catalog is dropped.
		if slot >= 0:
			level_stars[slot] = maxi(level_stars[slot], stars)
		elif catalog == null or catalog.entry_of(id) != null:
			practice_stars[id] = stars


## A code's stars by today's slots. A code from an older version is read against
## the slots it was written with, and each level's stars move to where that
## level sits now.
func _decode(code: String) -> PackedInt32Array:
	var decoded := ProgressCode.decode(code)
	if decoded.is_empty() or ProgressCode.version_of(code) >= ProgressCode.VERSION:
		return decoded

	var moved := PackedInt32Array()
	moved.resize(ProgressCode.LEVELS)
	moved.fill(0)
	for old_slot in mini(V1_SLOTS.size(), decoded.size()):
		var slot := slot_of(V1_SLOTS[old_slot])
		if slot >= 0:
			moved[slot] = decoded[old_slot]
	return moved


func _save_to_disk() -> void:
	if not _disk_available:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("progress", "code", get_code())
	cfg.set_value("progress", "stars", total_stars())
	cfg.set_value("progress", "saved_at", Time.get_datetime_string_from_system(true))
	for id in practice_stars:
		cfg.set_value("practice", String(id), practice_stars[id])

	var err := cfg.save(SAVE_PATH)
	if err != OK:
		# Said once: a machine that can't write user:// fails every save, and a
		# warning per save would hide everything else.
		_disk_available = false
		push_warning(
			"Progress: cannot write %s (error %d). Progress will survive this session only, "
			% [SAVE_PATH, err] + "students on this machine must copy their progress code."
		)
