@tool
class_name LevelCatalog
extends Resource

## The single source of truth for what levels exist, what order they are in, and
## which ProgressCode slot each one owns.
##
## Everything else derives from this: the level select grid, the Progress star
## array, the level id written into a progress code, and the lint pass. Adding a
## level is editing this resource, no scene rewiring, no second list to keep in
## sync.
##
## Slot rule: a level's ProgressCode slot is its position in the flattened
## catalog, skipping entries with `counts_for_progress = false`. Slots are
## therefore stable as long as you only ever APPEND to a module and never
## reorder or delete a shipped one. If you must remove a level after codes have
## been handed out, set `retired = true` instead of deleting it, that holds the
## slot and keeps every code already in students' hands readable.

@export var modules: Array[LevelModule] = []

## Levels beyond the furthest one reached stay locked. The Iteration set is a
## scaffold-then-fade sequence, so out-of-order play breaks the teaching order.
@export var sequential_unlock := true

## How many levels past the last completed one stay open. 1 = the next one.
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


## ProgressCode slot for a level id, or -1 when the id is not in the catalog.
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


## Entries whose id is not unique, or that are missing a scene. Used by the lint
## pass and by _validate() below so a broken catalog is loud in the editor.
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
