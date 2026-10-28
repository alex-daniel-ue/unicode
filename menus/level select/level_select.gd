extends Control

## Level select, built from the LevelCatalog.
##
## Every static button is connected in level_select.tscn, not here. The only
## programmatic connections are on the level buttons themselves, which do not
## exist until the catalog is read. The handlers below are all zero-argument so
## they connect straight from `pressed`, except _apply_code(), which the Enter
## key reaches through `text_submitted` with Unbind set to 1.

const CONFIG_FILE := "unicode.cfg"
## Checked second. The codebase notes told people to put [levels] here, beside
## the relay settings, so honour it rather than silently ignore it.
const AI_CONFIG_FILE := "unicode_ai.cfg"
## A locked tile's number and lock; the module dots, lit and not.
const DIM := Color("4a6385")
const DOT_LIT := Color("5ef0f2")
const DOT := Color("2e3f63")
const STAR_FULL := preload("res://menus/level select/art/star_full.png")
const STAR_EMPTY := preload("res://menus/level select/art/star_empty.png")
const LOCK := preload("res://menus/level select/art/lock.png")
const NEXT_ARROW := preload("res://menus/level select/art/next_arrow.png")
## Down a tile, from the top of its outline: where the number's digits start,
## and where the stars or the lock under them start.
const NUMBER_TOP := 26.0
const MARKS_TOP := 70.0
const STAR_GAP := 4.0
## How far down the space the column doesn't fill it sits: a little above the
## middle, with more room under the tiles than over the header.
const COLUMN_RISE := 0.355

@export_group("Wiring")
@export var module_label: Label
@export var module_subtitle: Label
@export var module_dots: HBoxContainer
@export var grid: HFlowContainer
@export var locked_notice: Label
@export var prev_button: Button
@export var next_button: Button
## The header and the tiles, kept centred as the window changes.
@export var column: Control

@export_group("Appearance")
## A tile with its outline; the next level's ring is drawn outside it.
@export var button_size := Vector2(160, 132)
@export var columns := 5

var _catalog: LevelCatalog
var _module_index := 0
## The module last looked at, for coming back to level select this session.
## Opening on the module of the level just played comes first; this covers
## paging to a module and leaving through Home without playing.
static var _last_module_id: StringName = &""
## Module ids force-opened by unicode.cfg, overriding LevelModule.released.
var _released_override: PackedStringArray = []
var _override_active := false


func _ready() -> void:
	_catalog = Progress.catalog
	if _catalog == null:
		push_error("LevelSelect: Progress has no catalog; nothing to show.")
		return

	_load_release_config()

	# As wide as `columns` tiles: the flow wraps after that many, and centres a
	# row that has fewer.
	if grid != null and column != null:
		var across := grid.get_theme_constant(&"h_separation")
		column.size.x = columns * button_size.x + (columns - 1) * across
	resized.connect(_layout)
	_layout()

	if module_dots != null:
		for i in _catalog.modules.size():
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(8, 8)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			module_dots.add_child(dot)

	Progress.progress_updated.connect(_refresh)

	_module_index = _remembered_module()
	_refresh()

## The column centred across the window and COLUMN_RISE down it, on whole
## pixels so the pixel art stays crisp.
func _layout() -> void:
	if column != null:
		column.position = ((size - column.size) * Vector2(0.5, COLUMN_RISE)).round()

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
	var found := false
	for file in [CONFIG_FILE, AI_CONFIG_FILE]:
		config = ConfigFile.new()
		if config.load(folder.path_join(file)) == OK and config.has_section_key("levels", "released"):
			found = true
			break
	if not found:
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


## Where the student left off: the module of the level they last opened, else
## the module they last looked at, else the first one that's open. Always
## landing on Tutorial after a level in another module was jarring.
func _remembered_module() -> int:
	for wanted: StringName in [_module_id_of(Game.level_id), _last_module_id]:
		if wanted.is_empty():
			continue
		for i in _catalog.modules.size():
			if _catalog.modules[i].id == wanted and _is_released(_catalog.modules[i]):
				return i
	return _first_open_module()

func _module_id_of(level_id: StringName) -> StringName:
	if level_id.is_empty():
		return &""
	var module := _catalog.module_of(level_id)
	return module.id if module != null else &""


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
	_last_module_id = module.id

	if module_label != null:
		module_label.text = module.display_name
	if module_subtitle != null:
		module_subtitle.text = module.subtitle
		module_subtitle.visible = not module.subtitle.is_empty()
	if module_dots != null:
		for i in module_dots.get_child_count():
			(module_dots.get_child(i) as ColorRect).color = DOT_LIT if i == _module_index else DOT

	if prev_button != null:
		prev_button.disabled = _module_index == 0
	if next_button != null:
		next_button.disabled = _module_index >= _catalog.modules.size() - 1

	if locked_notice != null:
		locked_notice.text = module.locked_notice
		locked_notice.visible = not released
	if grid != null:
		grid.visible = released
	
	if released:
		_build_grid(module)

func _build_grid(module: LevelModule) -> void:
	if grid == null:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var buttons: Array = []
	# The first open level not yet solved is the one to play next.
	var next_found := false
	for entry in module.levels:
		if entry == null or entry.retired:
			continue
		var is_next := not next_found and _lock_reason(entry).is_empty() and not Progress.is_complete(entry.id)
		next_found = next_found or is_next
		var button := _build_button(entry, is_next)
		grid.add_child(button)
		buttons.append(button)
		# The level just played has the focus, so it's where the eye lands.
		if entry.id == Game.level_id and not button.disabled:
			button.grab_focus.call_deferred()
	UiMotion.stagger_in(buttons)
	if module_label != null:
		UiMotion.fade_in(module_label, 0.18)


## A level's tile: its number, and under it three stars, the earned ones gold,
## or a lock. The next level to play has a ring round it (LevelTileNext) and
## an arrow over it. The tile's look per state is main_theme.tres's; its
## number and marks sit in the same place in every state.
func _build_button(entry: LevelEntry, next := false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.theme_type_variation = &"LevelTileNext" if next else &"LevelTile"

	var stars := Progress.get_stars(entry.id)
	var reason := _lock_reason(entry)
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason if not reason.is_empty() else _tooltip(entry, stars)

	var number := Label.new()
	number.theme_type_variation = &"LevelTileNumber"
	number.text = entry.label
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	number.position.y = NUMBER_TOP - _digit_top()
	if button.disabled:
		number.add_theme_color_override(&"font_color", DIM)
	button.add_child(number)

	var marks: Array[Texture2D] = []
	if button.disabled:
		marks.append(LOCK)
	else:
		for i in 3:
			marks.append(STAR_FULL if i < stars else STAR_EMPTY)
	_add_marks(button, marks)

	if next:
		var arrow := TextureRect.new()
		arrow.texture = NEXT_ARROW
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 8 px over the ring, which is 4 px outside the tile.
		arrow.position = Vector2(floorf((button_size.x - NEXT_ARROW.get_width()) / 2.0), -12.0 - NEXT_ARROW.get_height())
		button.add_child(arrow)

	if not button.disabled:
		button.pressed.connect(_on_level_pressed.bind(entry))
	return button

## `marks` side by side, centred across `button` at MARKS_TOP, on whole pixels.
func _add_marks(button: Button, marks: Array[Texture2D]) -> void:
	var width := -STAR_GAP
	for mark in marks:
		width += mark.get_width() + STAR_GAP
	var x := floorf((button_size.x - width) / 2.0)
	for mark in marks:
		var shown := TextureRect.new()
		shown.texture = mark
		shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shown.position = Vector2(x, MARKS_TOP)
		button.add_child(shown)
		x += mark.get_width() + STAR_GAP

## How far below the top of a tile number's line its digits start: the font's
## ascent less the digits' height, which in Kenney Mini is five eighths of its
## size. Asked of this scene, since a new tile isn't in the tree to have the
## theme yet.
func _digit_top() -> float:
	var font := get_theme_font(&"font", &"LevelTileNumber")
	var font_size := get_theme_font_size(&"font_size", &"LevelTileNumber")
	return roundf(font.get_ascent(font_size) - font_size * 0.625)


func _tooltip(entry: LevelEntry, stars: int) -> String:
	var lines: PackedStringArray = []
	if not entry.title.is_empty():
		lines.append(entry.title)
	if not entry.concept.is_empty():
		lines.append(entry.concept)
	if stars > 0:
		lines.append("Best: %d of 3 stars" % stars)
	return "\n".join(lines)


## Empty when the level is playable; otherwise the message the student sees.
func _lock_reason(entry: LevelEntry) -> String:
	if entry.scene == null:
		return "This level isn't built yet."
	if Progress.is_unlocked(entry.id):
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
