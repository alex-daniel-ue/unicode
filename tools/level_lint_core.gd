class_name LevelLint
extends RefCounted

## The level lint's checks, shared by the two ways to run it: the editor script
## (tools/level_lint.gd, Ctrl+Shift+X in the script editor) and a headless scene
## (tools/level_lint.tscn), so it can run from a terminal too:
##   godot --headless --path . res://tools/level_lint.tscn
##
## Every check here corresponds to a failure that is invisible in the editor and
## silent at runtime, the class of bug that makes a level quietly too easy
## rather than visibly broken. With roughly a hundred prop placements coming
## across twenty levels, and no pilot test scheduled, this is the cheapest way
## to keep a mis-wired level from reaching a student.
##
## It reads scenes without adding them to the tree, so no _ready() runs and
## nothing it touches can change the project.

const CATALOG_PATH := "res://global/utils/level_catalog.tres"

var errors := 0
var warnings := 0


func run() -> void:
	print_rich("\n[b]Level lint[/b]")
	print("".lpad(60, "-"))

	var catalog := load(CATALOG_PATH) as LevelCatalog
	if catalog == null:
		printerr("No LevelCatalog at %s." % CATALOG_PATH)
		return

	for problem in catalog.problems():
		_error("catalog", problem)

	for entry in catalog.all_entries():
		if entry.retired:
			continue
		if entry.scene == null:
			_warn(String(entry.id), "No scene assigned yet.")
			continue
		_check_level(entry, catalog)

	print("".lpad(60, "-"))
	if errors == 0 and warnings == 0:
		print_rich("[color=green]Clean, %d levels checked.[/color]" % catalog.all_entries().size())
	else:
		print_rich("[color=%s]%d error(s), %d warning(s).[/color]"
			% ["red" if errors > 0 else "yellow", errors, warnings])


func _check_level(entry: LevelEntry, _catalog: LevelCatalog) -> void:
	var root := entry.scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var level := root as Level
	if level == null:
		_error(String(entry.id), "Scene root is not a Level.")
		root.free()
		return

	var where := String(entry.id)

	_check_rooms(where, level)
	_check_goals(where, level)
	_check_resettables(where, level)
	_check_preset(where, level)
	_check_props(where, level)
	_check_lists(where, level)
	_check_brief(where, entry)
	_check_par(where, level)

	root.free()


#region Checks
func _check_rooms(where: String, level: Level) -> void:
	# The default state of any scene freshly inherited from level.tscn. Fails
	# closed at runtime now, but it fails closed *in front of a student*.
	if level.room_goals.is_empty():
		_error(where, "room_goals is empty, the level cannot be solved. Step 6 of the authoring checklist.")
		return

	for i in level.room_goals.size():
		if level.room_goals[i] == null:
			_error(where, "room_goals[%d] is null." % i)
			continue
		var manager := level.room_goals[i]
		if not (manager.get_parent() is RoomGoals):
			_error(where, "GoalManager '%s' is not under a RoomGoals node; it will crash on load." % manager.name)
		if not manager.bounds.has_area():
			_warn(where, "Room %d ('%s') has no baked camera bounds, the camera will fall back to the whole level."
				% [i + 1, manager.name])

	# A manager that exists but was never listed runs never.
	var listed: Dictionary[Node, bool] = {}
	for manager in level.room_goals:
		if manager != null:
			listed[manager] = true
	for manager in _find_all(level, "GoalManager"):
		# An empty one is just level.tscn's template manager left unused, which
		# is harmless. One holding goals that never run is the real danger.
		var has_goals := manager.get_children().any(func(c: Node) -> bool: return c is Goal)
		if not listed.has(manager) and has_goals:
			_warn(where, "GoalManager '%s' exists but is not in room_goals, so its goals are never checked."
				% manager.name)


func _check_goals(where: String, level: Level) -> void:
	for i in level.room_goals.size():
		var manager := level.room_goals[i]
		if manager == null:
			continue

		var goals: Array[Goal] = []
		for child in manager.get_children():
			if child is Goal:
				goals.append(child as Goal)

		if goals.is_empty():
			_error(where, "Room %d has a GoalManager with no Goal children, any program passes it." % [i + 1])

		var has_win := false
		for goal in goals:
			var tag := "room %d / %s" % [i + 1, goal.name]

			if goal.needs_detection() and goal.detection_area == null:
				_error(where, "%s reacts to contact but has no detection_area, so nothing will trigger it." % tag)

			if goal.has_method("check_condition") and goal.get("destination_area") != null:
				has_win = true
			if goal.get("required_entity") == null and ("required_entity" in goal):
				_error(where, "%s has no required_entity." % tag)

			if "destination_area" in goal and goal.get("destination_area") == null:
				_error(where, "%s has no destination_area; check_condition() will crash." % tag)

			# A ListGoal writes its own message from the two lists, and its list
			# is measured for the camera through the shelf rather than a focus.
			if goal is ListGoal:
				continue

			if goal.fail_message.strip_edges().is_empty():
				_warn(where, "%s has no fail_message, so the student is told only 'The room wasn't solved correctly.'" % tag)

			if goal.camera_focus == null:
				_warn(where, "%s has no camera_focus, so it contributes nothing to baked bounds." % tag)

		if not has_win:
			_warn(where, "Room %d has no DestinationGoal, check this is deliberate." % [i + 1])


func _check_resettables(where: String, level: Level) -> void:
	var rooms := maxi(level.room_goals.size(), 1)
	var robots := _find_all(level, "Robot")

	if robots.is_empty():
		_error(where, "No Robot in the level.")
	elif robots.size() > 1:
		_warn(where, "%d robots found. Goals bind to one entity; make sure that is intended." % robots.size())

	var found_any := false
	for node in _walk(level):
		if not (node is Resettable):
			continue
		found_any = true
		var res := node as Resettable

		if res.base == null:
			_error(where, "A Resettable has no base node set.")
			continue

		if res.room_snapshots.size() < rooms:
			# Runtime only warns and leaves the entity where the last room left
			# it, which usually makes room 2 unsolvable or trivially solvable.
			_error(where, "'%s' has %d snapshot(s) for %d room(s); rooms past %d never reset."
				% [res.base.name, res.room_snapshots.size(), rooms, res.room_snapshots.size()])

		for prop in res.tracked_properties:
			if not (prop in res.base):
				_error(where, "'%s' tracks a property '%s' its base does not have." % [res.base.name, prop])

		for snap_index in res.room_snapshots.size():
			var snap: Dictionary = res.room_snapshots[snap_index]
			for prop in res.tracked_properties:
				if not snap.has(prop):
					_warn(where, "'%s' snapshot %d is missing '%s'." % [res.base.name, snap_index, prop])

	if not found_any:
		_error(where, "Nothing in the level is Resettable, so a retry will not restore the starting state.")


func _check_preset(where: String, level: Level) -> void:
	if level.preset == null:
		_error(where, "Level.preset is not set.")
		return

	var tops := 0
	for child in level.preset.get_children():
		if child is Block:
			tops += 1
	if tops == 0:
		_error(where, "The block preset has no Block, the level will report 'No begin block on Canvas.'")
	elif tops > 1:
		# get_preset() keeps the LAST Block child, so a second top-level block
		# silently replaces Begin rather than adding scaffolding.
		_error(where, "The block preset has %d top-level blocks. Only the last survives, and it replaces Begin. Nest scaffolding inside Begin's mouth." % tops)


func _check_props(where: String, level: Level) -> void:
	for node in _walk(level):
		if not (node is Area2D):
			continue
		if node is SensedArea:
			var tagged := node as SensedArea
			if tagged.tag == &"":
				_warn(where, "SensedArea '%s' has an empty tag." % tagged.name)
			elif tagged.tag == &"undetectable":
				pass  # deliberate: a goal area the robot is never meant to sense
			elif not (tagged.tag in Robot.TAGS):
				_warn(where, "SensedArea '%s' has tag '%s', which the robot can never sense. Tag it 'undetectable' if that's deliberate."
					% [tagged.name, tagged.tag])
		else:
			# The classifier excludes every Area2D from the blocked channel, so
			# an untagged prop is invisible to sensing rather than solid.
			_warn(where, "Area2D '%s' has no SensedArea script, so ahead_is() cannot see it at all."
				% node.name)


## The room's lists. Each failure here shows up at runtime only in the one room
## it affects, as "There's no list named 'x' in Room 2" or as a goal no program
## can meet.
func _check_lists(where: String, level: Level) -> void:
	var rooms := maxi(level.room_goals.size(), 1)
	var by_name: Dictionary[StringName, Array] = {}

	for node in _find_all(level, "ListEntity"):
		var list := node as ListEntity
		var list_name := list.get_list_name()
		if list.get_node_or_null(^"Slots") == null:
			_error(where, "'%s' is the ListEntity script on its own. Instance list_entity.tscn instead." % list_name)
		if not String(list_name).is_valid_ascii_identifier() or String(list_name) in Core.PYTHON_KEYWORDS:
			_error(where, "'%s' isn't a name a Python list could have." % list_name)
		if list.room_index < 0 or list.room_index >= rooms:
			_error(where, "'%s' has room_index %d, but the level has %d room(s), counted from 0." % [list_name, list.room_index, rooms])
		by_name.get_or_add(list_name, []).append(list)

	for list_name in by_name:
		var shelves: Array = by_name[list_name]
		if shelves.size() == 1:
			continue  # one shelf serves every room
		var seen: Dictionary[int, bool] = {}
		for list: ListEntity in shelves:
			if seen.has(list.room_index):
				_error(where, "Two shelves named '%s' in Room %d. The name block can only find one." % [list_name, list.room_index + 1])
			seen[list.room_index] = true
		for room in rooms:
			if not seen.has(room):
				_error(where, "Room %d has no shelf named '%s', so any block using it errors there." % [room + 1, list_name])

	for i in level.room_goals.size():
		var manager := level.room_goals[i]
		if manager == null:
			continue
		for child in manager.get_children():
			if not (child is ListGoal):
				continue
			var goal := child as ListGoal
			var tag := "room %d / %s" % [i + 1, goal.name]
			if goal.list == null:
				_error(where, "%s has no list, so it can't be checked." % tag)
				continue
			var shared: bool = by_name.get(goal.list.get_list_name(), []).size() == 1
			if not shared and goal.list.room_index != i:
				_error(where, "%s checks the Room %d shelf of '%s'." % [tag, goal.list.room_index + 1, goal.list.get_list_name()])
			if goal.list.kind != ListEntity.Kind.TUPLE and goal.expected.size() > goal.list.cubby_count():
				_error(where, "%s expects %d items, but the shelf has %d cubbies, so no program can fill it. Raise its capacity."
					% [tag, goal.expected.size(), goal.list.cubby_count()])
			for value: Variant in goal.expected:
				# The inspector makes it easy to type "3" as a string.
				if typeof(value) == TYPE_STRING and String(value).is_valid_float():
					_warn(where, "%s expects the text '%s'. If that's meant to be a number, it will never match." % [tag, value])


func _check_brief(where: String, entry: LevelEntry) -> void:
	# The table backs up brief fields the editor has dropped from scenes before.
	if LevelBriefs.for_scene(entry.scene.resource_path).is_empty():
		_warn(where, "No LevelBriefs entry for '%s', so nothing backs up its brief if the scene loses it."
			% entry.scene.resource_path.get_file().get_basename())


func _check_par(where: String, level: Level) -> void:
	if level.intended_solution.strip_edges().is_empty():
		_error(where, "intended_solution is empty, so star par falls back to 1 and every solve is three stars.")
		return

	var par := Serializer.count_solid_blocks(level.intended_solution, true)
	if par <= 0:
		# Zero placed blocks is right for a worked example, where the preset is
		# the whole program. It is only wrong when there are no blocks at all.
		if Serializer.count_solid_blocks(level.intended_solution, false) <= 0:
			_error(where, "intended_solution parses to 0 blocks. Regenerate it from the in-game debug print.")
			return
		print("  %s: worked example, every block is preset; completing it is 3 stars" % where)
		return

	# Mirrors Level.get_star_par() from exported values. Level isn't @tool, so in
	# the editor it's a placeholder and its methods can't be called.
	var effective: int = level.star_par_override if level.star_par_override > 0 else maxi(1, par)
	print("  %s: par %d, 2 stars at %d, id '%s'" % [where, effective, effective + level.star_slack, where])

	# The star target is written into the level text by hand today. Catch the
	# drift rather than trusting nobody edited one without the other.
	if level.description == null:
		_warn(where, "Level.description is not set.")
		return

	var text := _description_text(level)
	var regex := RegEx.new()
	regex.compile(r"(\d+)\s*blocks?")
	for found in regex.search_all(text):
		var claimed := int(found.get_string(1))
		if claimed != effective and claimed != effective + level.star_slack:
			_warn(where, "Level text promises %d blocks but par is %d (2 stars at %d)."
				% [claimed, effective, effective + level.star_slack])


func _description_text(level: Level) -> String:
	var parts: PackedStringArray = []
	for node in _walk(level.description):
		if node is Label:
			parts.append((node as Label).text)
		elif node is RichTextLabel:
			parts.append((node as RichTextLabel).text)
	return "\n".join(parts)
#endregion


#region Helpers
func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		stack.append_array(node.get_children())
	return out


func _find_all(root: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	for node in _walk(root):
		if node.is_class(type_name):
			out.append(node)
			continue
		var script := node.get_script() as Script
		while script != null:
			if script.get_global_name() == StringName(type_name):
				out.append(node)
				break
			script = script.get_base_script()
	return out


func _error(where: String, message: String) -> void:
	errors += 1
	printerr("  [%s] %s" % [where, message])


func _warn(where: String, message: String) -> void:
	warnings += 1
	print_rich("  [color=yellow][%s] %s[/color]" % [where, message])
#endregion
