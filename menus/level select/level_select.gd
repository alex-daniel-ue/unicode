extends Control

## Level select, built from the LevelCatalog.
##
## Every static button is connected in level_select.tscn, not here. The only
## programmatic connections are on the level buttons themselves, which do not
## exist until the catalog is read. The handlers below are all zero-argument so
## they connect straight from `pressed`, except _apply_code(), which the Enter
## key reaches through `text_submitted` with Unbind set to 1.

const CONFIG_FILE := "unicode.cfg"
const STAR_FILLED := "★"
const STAR_EMPTY := "☆"

@export_group("Wiring")
@export var module_label: Label
@export var module_subtitle: Label
@export var grid: GridContainer
@export var locked_notice: Label
@export var prev_button: Button
@export var next_button: Button

@export_group("Progress code")
@export var code_label: Label
@export var copy_button: Button
@export var import_edit: LineEdit
@export var import_feedback: Label
@export var import_popup: PopupPanel

@export_group("Appearance")
@export var button_size := Vector2(120, 85)
@export var columns := 5

var _catalog: LevelCatalog
var _module_index := 0
## Module ids force-opened by unicode.cfg, overriding LevelModule.released.
var _released_override: PackedStringArray = []
var _override_active := false


func _ready() -> void:
	_catalog = Progress.catalog
	if _catalog == null:
		push_error("LevelSelect: Progress has no catalog; nothing to show.")
		return

	_load_release_config()

	if grid != null:
		grid.columns = columns

	Progress.progress_updated.connect(_refresh)

	_module_index = _first_open_module()
	_refresh()

#region Deployment gate
## Reuses the config file that already sits beside the executable for the relay
## URL, so opening a module on lab day is a text edit rather than a rebuild:
##
##     [levels]
##     released="iteration"
##
## Leave the key out and each module's own `released` flag decides. Comma
## separate to open more than one.
func _load_release_config() -> void:
	var folder := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir()

	var config := ConfigFile.new()
	if config.load(folder.path_join(CONFIG_FILE)) != OK:
		return
	if not config.has_section_key("levels", "released"):
		return

	_override_active = true
	for piece in str(config.get_value("levels", "released", "")).split(",", false):
		_released_override.append(piece.strip_edges().to_lower())


func _is_released(module: LevelModule) -> bool:
	if module == null:
		return false
	if _override_active:
		return String(module.id).to_lower() in _released_override
	return module.released


func _first_open_module() -> int:
	for i in _catalog.modules.size():
		if _is_released(_catalog.modules[i]):
			return i
	return 0
#endregion

#region Display
func _refresh() -> void:
	if _catalog == null or _catalog.modules.is_empty():
		return

	_module_index = clampi(_module_index, 0, _catalog.modules.size() - 1)
	var module := _catalog.modules[_module_index]
	var released := _is_released(module)

	if module_label != null:
		module_label.text = module.display_name
	if module_subtitle != null:
		module_subtitle.text = module.subtitle
		module_subtitle.visible = not module.subtitle.is_empty()

	if prev_button != null:
		prev_button.disabled = _module_index == 0
	if next_button != null:
		next_button.disabled = _module_index >= _catalog.modules.size() - 1

	if locked_notice != null:
		locked_notice.text = module.locked_notice
		locked_notice.visible = not released
	if grid != null:
		grid.visible = released

	_refresh_code()

	if released:
		_build_grid(module)


func _refresh_code() -> void:
	if code_label != null:
		code_label.text = Progress.get_code()
	if copy_button != null:
		copy_button.disabled = Progress.total_stars() == 0


func _build_grid(module: LevelModule) -> void:
	if grid == null:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var furthest := Progress.furthest_slot()

	for entry in module.levels:
		if entry == null or entry.retired:
			continue
		grid.add_child(_build_button(entry, furthest))


func _build_button(entry: LevelEntry, furthest_slot: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.theme_type_variation = &"MainMenuButton"
	button.clip_text = true

	var stars := Progress.get_stars(entry.id)
	button.text = "%s\n%s" % [entry.label, _star_text(entry, stars)]

	var reason := _lock_reason(entry, furthest_slot)
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason if not reason.is_empty() else _tooltip(entry, stars)

	if not button.disabled:
		button.pressed.connect(_on_level_pressed.bind(entry))
	return button


func _star_text(entry: LevelEntry, stars: int) -> String:
	if not entry.counts_for_progress:
		return ""
	return STAR_FILLED.repeat(stars) + STAR_EMPTY.repeat(3 - stars)


func _tooltip(entry: LevelEntry, stars: int) -> String:
	var lines: PackedStringArray = []
	if not entry.title.is_empty():
		lines.append(entry.title)
	if not entry.concept.is_empty():
		lines.append(entry.concept)
	if entry.counts_for_progress:
		lines.append("Best: %d of 3 stars" % stars)
	return "\n".join(lines)


## Empty when the level is playable; otherwise the message the student sees.
func _lock_reason(entry: LevelEntry, furthest_slot: int) -> String:
	if entry.scene == null:
		return "This level isn't built yet."
	if not _catalog.sequential_unlock or not entry.counts_for_progress:
		return ""

	var slot := _catalog.slot_of(entry.id)
	if slot < 0:
		return ""
	if slot <= furthest_slot + _catalog.unlock_lookahead:
		return ""
	return "Finish the level before this one first."
#endregion

#region Handlers, all connected in level_select.tscn
func _on_level_pressed(entry: LevelEntry) -> void:
	# The scene is handed over rather than instantiated here. Instantiating at
	# button-press time left an orphan Level node outside the tree whenever the
	# transition did not complete, and made Puzzle guess the level's identity
	# from its filename.
	Game.level_scene = entry.scene
	Game.level_id = entry.id
	Transition.change_scene(Core.PUZZLE_CANVAS)


func _on_home_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)


## Looks for the catalog entry with id "tutorial".
func _on_tutorial_pressed() -> void:
	var entry := _catalog.entry_of(&"tutorial") if _catalog != null else null
	if entry == null or entry.scene == null:
		push_warning("LevelSelect: no catalog entry with id 'tutorial', or it has no scene.")
		return
	Game.level_scene = entry.scene
	Game.level_id = entry.id
	Transition.change_scene(Core.PUZZLE_CANVAS)


func _on_prev_pressed() -> void:
	_module_index -= 1
	_refresh()


func _on_next_pressed() -> void:
	_module_index += 1
	_refresh()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(Progress.get_code())
	if copy_button == null:
		return
	copy_button.text = "Copied"
	get_tree().create_timer(1.5).timeout.connect(
		func() -> void:
			if is_instance_valid(copy_button):
				copy_button.text = "Copy"
	)


## Connect this to the Import button's `pressed` alongside ImportPopup's
## popup_centered, so the field starts empty and focused.
func _on_import_opened() -> void:
	if import_feedback != null:
		import_feedback.text = ""
	if import_edit != null:
		import_edit.clear()
		import_edit.grab_focus()


## Reachable from the Import button's `pressed` and from the field's
## `text_submitted` with Unbind set to 1. It says so when a code is rejected:
## silently doing nothing is the worst outcome for a student who has just typed
## ten characters off a piece of paper.
func _apply_code() -> void:
	if import_edit == null:
		return

	var code := import_edit.text.strip_edges()
	if code.is_empty():
		_say("Type your code first.")
		return

	if not Progress.apply_code(code):
		_say("That code isn't readable. Check for a mistyped character.")
		return

	if import_popup != null:
		import_popup.hide()
	import_edit.clear()
	_refresh()


func _say(message: String) -> void:
	if import_feedback != null:
		import_feedback.text = message
	else:
		push_warning("LevelSelect: " + message)
#endregion
