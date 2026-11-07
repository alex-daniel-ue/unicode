class_name LevelComplete
extends Control
## The win card: the stars, the block count, the next star to go for, and the
## assistant's comment on the program. Puzzle shows it with present().
##
## A plain Control rather than a PopupPanel: a popup closes on Escape and on any
## outside click, and Escape is also the pause key. This one stays until a
## button is pressed.
##
## Everything on it comes from the game, never from the model, except the
## comment, which is the assistant's, fills in afterwards, and never carries a
## number the game worked out.

## The way out (Try for more stars, Level select, Next level) opens after
## MIN_HOLD, long enough that a click meant for the canvas doesn't skip the card.
## It never waits for the comment: offline, that wait would be the whole screen.
## The comment fills in whenever it arrives, or its line goes away.
const MIN_HOLD := 1.0
const SUMMARY_WAITING := "Looking at your program..."
const STAR_SIZE := 64
const STAR_RIM := Color(0.105882354, 0.09411765, 0.13725491)

@export var stars_label: HBoxContainer
## "You used 5 blocks." What the student did.
@export var usage_label: Label
## The next star tier only: "For ★★★, use 4 blocks or fewer." Hidden at three
## stars. Rich text, so the stars can be set in StarText's font.
@export var target_label: RichTextLabel
## The assistant's comment, hidden until it has text. Rich text, so the Python
## in it shows as code (CodeSpans) instead of running on as English. Its code
## font is the scene's mono_font.
@export var summary_label: RichTextLabel
## The assistant's badge and the bubble the comment is in: shown with it.
@export var summary_row: Control
@export var stay_button: Button
@export var select_button: Button
@export var next_button: Button

var _next: LevelEntry
var _released := false
## Bumped per present(), so a timer or a comment left over from an earlier win
## (Try for more stars, then win again) can't release or fill a newer card.
var _presentation := 0


func _ready() -> void:
	visible = false


## Shows the card for a win, and gives the number show_summary() wants with
## the comment.
func present(stars: int, placed: int, par: int, slack: int, summary_expected := false) -> int:
	StarText.fill(stars_label, stars, STAR_SIZE, STAR_RIM, 8)

	if placed == 0:
		# A worked example: the preset was the whole program.
		usage_label.text = "You ran the program as written."
		target_label.visible = false
	else:
		usage_label.text = "You used %d block%s." % [placed, "" if placed == 1 else "s"]
		target_label.text = _next_tier(stars, par, slack)
		target_label.visible = not target_label.text.is_empty()

	summary_label.text = SUMMARY_WAITING if summary_expected else ""
	summary_label.modulate.a = 0.6 if summary_expected else 1.0
	summary_row.visible = summary_expected

	_next = _find_next()
	next_button.visible = _next != null

	_released = false
	stay_button.disabled = true
	select_button.disabled = true
	next_button.disabled = true
	_presentation += 1
	show()
	UiMotion.fade_in(get_node(^"Dim"), 0.25)
	UiMotion.pop_in(get_node(^"Center/Card"), 0.26)
	_bounce_stars()
	get_tree().create_timer(MIN_HOLD).timeout.connect(_try_release.bind(_presentation))
	return _presentation


## Called by Puzzle when the comment's request finishes. Empty means it failed
## or timed out, and the section is left out rather than shown half-empty.
func show_summary(text: String, presentation: int) -> void:
	if not is_instance_valid(self) or presentation != _presentation:
		return
	summary_label.modulate.a = 1.0
	summary_label.text = CodeSpans.to_bbcode(text) if not text.is_empty() else ""
	summary_row.visible = not text.is_empty()
	if summary_row.visible:
		UiMotion.fade_in(summary_label, 0.3)


## The stars land a moment after the card, with a bounce: the one bit of this
## screen that is pure reward.
func _bounce_stars() -> void:
	stars_label.modulate.a = 0.0
	await get_tree().process_frame
	stars_label.pivot_offset = stars_label.size / 2.0
	stars_label.scale = Vector2(0.3, 0.3)
	var tween := stars_label.create_tween()
	tween.tween_interval(0.18)
	tween.tween_property(stars_label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(stars_label, "scale", Vector2(1.18, 1.18), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stars_label, "scale", Vector2.ONE, 0.12)


## Only the next rung up, and nothing at three stars: both thresholds every time
## read as a verdict, even on a perfect solve.
func _next_tier(stars: int, par: int, slack: int) -> String:
	match stars:
		3:
			return ""
		2:
			return _tier_line(3, par)
		_:
			return _tier_line(2, par + slack)


func _tier_line(stars: int, blocks: int) -> String:
	return "[center]For %s, use %d block%s or fewer.[/center]" % [
		StarText.bbcode(StarText.FILLED.repeat(stars)), blocks, "" if blocks == 1 else "s"]


func _try_release(presentation: int) -> void:
	if not is_instance_valid(self) or _released or presentation != _presentation:
		return
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
		if not Progress.is_unlocked(entry.id):
			return null
		return entry
	return null


#region Buttons, connected in level_complete.tscn
func _on_stay_pressed() -> void:
	hide()


func _on_select_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)


func _on_next_pressed() -> void:
	if _next != null:
		Game.play(_next)
#endregion
