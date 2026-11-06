@tool
class_name LevelCatalog
extends Resource
## Every level, in order, and the ProgressCode slot each one owns.
##
## Level select's grid, the Progress star array, the level id in a progress code
## and the lint all read this, so adding a level is adding an entry here.
##
## Slot rule: a level's slot is its position in the flattened catalog, skipping
## entries with `counts_for_progress = false`. Slots stay put as long as levels
## are only appended to a module. A level pulled after codes were handed out is
## set `retired = true` rather than deleted: it keeps its slot, so every code
## already in students' hands still reads.

@export var modules: Array[LevelModule] = []
## Levels beyond the furthest one solved in their module stay locked, practice
## levels included: each module builds on itself, so playing out of order
## breaks the teaching order. See Progress.is_unlocked().
@export var sequential_unlock := true
## How many levels past the last solved one in a module stay open. 1 = the next one.
@export var unlock_lookahead := 1


func all_entries() -> Array[LevelEntry]:
	var out: Array[LevelEntry] = []
	for module in modules:
		if module == null:
			continue
		for entry in module.levels:
			if entry != null:
				out.append(entry)
	return out


## Flattened, progress-counting entries in slot order.
func scored_entries() -> Array[LevelEntry]:
	var out: Array[LevelEntry] = []
	for entry in all_entries():
		if entry.counts_for_progress:
			out.append(entry)
	return out


## ProgressCode slot for a level id, or -1 when it has none.
func slot_of(level_id: StringName) -> int:
	var slot := 0
	for entry in all_entries():
		if not entry.counts_for_progress:
			continue
		if entry.id == level_id:
			return slot
		slot += 1
	return -1


func entry_of(level_id: StringName) -> LevelEntry:
	for entry in all_entries():
		if entry.id == level_id:
			return entry
	return null


func module_of(level_id: StringName) -> LevelModule:
	for module in modules:
		if module == null:
			continue
		for entry in module.levels:
			if entry != null and entry.id == level_id:
				return module
	return null


## Ids that aren't unique, entries without a scene, and more scored levels than
## a progress code holds. Progress and the lint report them.
func problems() -> PackedStringArray:
	var issues: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}

	for entry in all_entries():
		if entry.id == &"":
			issues.append("A level entry has an empty id.")
			continue
		if seen.has(entry.id):
			issues.append("Duplicate level id '%s', two levels would share one progress slot." % entry.id)
		seen[entry.id] = true
		if entry.scene == null and not entry.retired:
			issues.append("Level '%s' has no scene assigned." % entry.id)

	var scored := scored_entries().size()
	if scored > ProgressCode.LEVELS:
		issues.append(
			"Catalog has %d scored levels but ProgressCode only stores %d. Raise ProgressCode.LEVELS (and bump VERSION)."
			% [scored, ProgressCode.LEVELS]
		)
	return issues
