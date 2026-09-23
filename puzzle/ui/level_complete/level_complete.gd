class_name LevelComplete
extends Control

## The win screen, as its own scene so Puzzle only has to call present().
##
## A plain Control rather than a PopupPanel, per design doc §7: a popup closes on
## Escape and on any outside click, and Escape is also the pause key. This one
## stays until a button is pressed, and holds the way out for a moment so the
## result is actually read.

## Seconds before Level select and Next level accept a click.
const HOLD := 2.0

@export var stars_label: Label
## "You used 5 blocks." What the student did.
@export var usage_label: Label
## "★★★ at 4 or fewer, ★★ at 5." What the stars were for, from star_par.
@export var target_label: Label
## Reserved for the post-win summary (design doc §8). Hidden until it has text.
@export var summary_label: Label
@export var code_label: Label
@export var copy_button: Button
@export var stay_button: Button
@export var select_button: Button
@export var next_button: Button

var _next: LevelEntry


func _ready() -> void:
	visible = false


## Everything the card shows comes from the game, never from the model: the
## design doc's rule for the one screen students screenshot.
func present(stars: int, placed: int, par: int, slack: int) -> void:
	stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)

	if placed == 0:
		# A worked example: the preset was the whole program.
		usage_label.text = "You ran the program as written."
		target_label.visible = false
	else:
		usage_label.text = "You used %d block%s." % [placed, "" if placed == 1 else "s"]
		target_label.text = "★★★ at %d or fewer, ★★ at %d." % [par, par + slack]
		target_label.visible = true

	summary_label.visible = not summary_label.text.is_empty()
	code_label.text = Progress.get_code()
	copy_button.text = "Copy"

	_next = _find_next()
	next_button.visible = _next != null

	select_button.disabled = true
	next_button.disabled = true
	show()
	get_tree().create_timer(HOLD).timeout.connect(_release)


func _release() -> void:
	if not is_instance_valid(self):
		return
	select_button.disabled = false
	next_button.disabled = false


## The next level in the same module, if it is built and unlocked. Completing
## this one has already been recorded, so a sequential unlock has moved on.
func _find_next() -> LevelEntry:
	var catalog := Progress.catalog
	if catalog == null:
		return null
	var module := catalog.module_of(Game.level_id)
	if module == null:
		return null

	var seen_current := false
	for entry in module.levels:
		if entry == null:
			continue
		if not seen_current:
			seen_current = entry.id == Game.level_id
			continue
		if entry.retired or entry.scene == null:
			continue
		if catalog.sequential_unlock and entry.counts_for_progress:
			var slot := catalog.slot_of(entry.id)
			if slot > Progress.furthest_slot() + catalog.unlock_lookahead:
				return null
		return entry
	return null


#region Buttons, connected in level_complete.tscn
func _on_stay_pressed() -> void:
	hide()


func _on_select_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)


func _on_next_pressed() -> void:
	if _next == null:
		return
	Game.level_scene = _next.scene
	Game.level_id = _next.id
	Transition.change_scene(Core.PUZZLE_CANVAS)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(Progress.get_code())
	copy_button.text = "Copied"
#endregion
