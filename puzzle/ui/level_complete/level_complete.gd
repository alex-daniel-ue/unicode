class_name LevelComplete
extends Control

## The win screen, as its own scene so Puzzle only has to call present().
##
## A plain Control rather than a PopupPanel, per design doc §7: a popup closes on
## Escape and on any outside click, and Escape is also the pause key. This one
## stays until a button is pressed, and holds the way out for a moment so the
## result is actually read.

## The way out -- Try for more stars, Level select, Next level -- opens once the
## post-win summary has arrived AND at least MIN_HOLD seconds have passed, so the
## summary is on screen long enough to be read. MAX_HOLD is the ceiling: a slow
## or dead relay can hold a student for fifteen seconds and no longer, because
## the summary must never block the game.
const MIN_HOLD := 5.0
const MAX_HOLD := 15.0
const SUMMARY_WAITING := "Looking at your program..."

@export var stars_label: Label
## "You used 5 blocks." What the student did.
@export var usage_label: Label
## The next star tier only: "★★★ takes 4 blocks or fewer." Hidden at three stars.
@export var target_label: Label
## Reserved for the post-win summary (design doc §8). Hidden until it has text.
@export var summary_label: Label
@export var stay_button: Button
@export var select_button: Button
@export var next_button: Button

var _next: LevelEntry
var _presented_ms := 0
var _summary_pending := false
var _released := false
## Bumped per present(), so a timer or a summary left over from an earlier win
## (Try for more stars, then win again) can't release or fill a newer card.
var _presentation := 0


func _ready() -> void:
	visible = false


## Everything the card shows comes from the game, never from the model: the
## design doc's rule for the one screen students screenshot. The summary is the
## one exception: it is the assistant's, it fills in afterwards, and it never
## carries a number the game computed.
func present(stars: int, placed: int, par: int, slack: int, summary_expected := false) -> int:
	stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)

	if placed == 0:
		# A worked example: the preset was the whole program.
		usage_label.text = "You ran the program as written."
		target_label.visible = false
	else:
		usage_label.text = "You used %d block%s." % [placed, "" if placed == 1 else "s"]
		target_label.text = _next_tier(stars, par, slack)
		target_label.visible = not target_label.text.is_empty()

	_summary_pending = summary_expected
	summary_label.text = SUMMARY_WAITING if summary_expected else ""
	summary_label.modulate.a = 0.6 if summary_expected else 1.0
	summary_label.visible = summary_expected

	_next = _find_next()
	next_button.visible = _next != null

	_released = false
	stay_button.disabled = true
	select_button.disabled = true
	next_button.disabled = true
	_presented_ms = Time.get_ticks_msec()
	_presentation += 1
	show()
	get_tree().create_timer(MIN_HOLD).timeout.connect(_try_release.bind(_presentation))
	get_tree().create_timer(MAX_HOLD).timeout.connect(_on_max_hold.bind(_presentation))
	return _presentation


## Only the next rung up, and nothing at three stars. Printing both thresholds
## every time read as a verdict even on a perfect solve.
func _next_tier(stars: int, par: int, slack: int) -> String:
	match stars:
		3:
			return ""
		2:
			return "★★★ takes %d block%s or fewer." % [par, "" if par == 1 else "s"]
		_:
			var two := par + slack
			return "★★ takes %d block%s or fewer." % [two, "" if two == 1 else "s"]


## Called by Puzzle when the summary request finishes. Empty means it failed or
## timed out, and the section is left out rather than shown half-empty.
func show_summary(text: String, presentation: int) -> void:
	if not is_instance_valid(self) or presentation != _presentation:
		return
	_summary_pending = false
	summary_label.modulate.a = 1.0
	summary_label.text = text
	summary_label.visible = not text.is_empty()
	_try_release(presentation)


func _try_release(presentation: int) -> void:
	if not is_instance_valid(self) or _released or presentation != _presentation:
		return
	var waited := (Time.get_ticks_msec() - _presented_ms) / 1000.0
	# A SceneTreeTimer can land a frame short of the wall clock; don't make the
	# student wait another frame's worth of nothing for it.
	if waited >= MIN_HOLD - 0.05 and not _summary_pending:
		_release()


func _on_max_hold(presentation: int) -> void:
	if not is_instance_valid(self) or _released or presentation != _presentation:
		return
	# Still waiting at the ceiling: drop the placeholder line. If the summary
	# turns up later it still appears; it just no longer holds anyone.
	if _summary_pending and summary_label.text == SUMMARY_WAITING:
		summary_label.visible = false
	_release()


func _release() -> void:
	_released = true
	stay_button.disabled = false
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
#endregion
