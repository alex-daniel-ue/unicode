class_name HintPool
extends RefCounted
## The assistant's question budget: a pool that refills, shared by every level.
##
## CAPACITY questions to start, one more every REFILL_SECONDS, and SOLVE_BONUS
## more the first time a level is solved, never above CAPACITY. Kept up, that is
## one question every three minutes, the limit CS50 set for its own AI tutor:
## enough to get unstuck, too few to have the assistant work a level out, and a
## student who asks twice after a long think isn't punished for it. The bonus
## means a student who spent the pool on one level can still ask on the next,
## and it is earned by solving, not by asking. Progress says when a level is
## solved for the first time on this computer.
##
## Shared across levels, since a per-level cap resets by opening the next level.
## Saved on this computer only, in SAVE_PATH, with the time it was last brought
## up to date, so it refills in real time while the game is closed, and
## restarting the game doesn't refill it at once. It is never part of the
## progress code or the study's data.
##
## The win card's comment doesn't draw from it (it is not a hint), and a request
## that never reached the model is given back (a dead relay is not the
## student's fault).

const CAPACITY := 10
const REFILL_SECONDS := 180.0
const SOLVE_BONUS := 3
const SAVE_PATH := "user://hint_pool.cfg"

static var _tokens := float(CAPACITY)
## When _tokens was last brought up to date, in Unix seconds. Below 0 until then.
static var _stamp := -1.0
static var _loaded := false
static var _disk_available := true


## Whole questions available right now.
static func available() -> int:
	_settle()
	return floori(_tokens)


## Spends one question. False, and nothing spent, when the pool is empty.
static func take() -> bool:
	_settle()
	if _tokens < 1.0:
		return false
	_tokens -= 1.0
	_save()
	return true


## Gives back a question whose request never produced a hint.
static func refund() -> void:
	_add(1.0)


## The bonus for a level solved for the first time on this computer.
static func reward_first_solve() -> void:
	_add(float(SOLVE_BONUS))


## Seconds until the next whole question comes back. 0 when the pool is full.
static func seconds_to_next() -> int:
	_settle()
	if _tokens >= float(CAPACITY):
		return 0
	return ceili((1.0 - fposmod(_tokens, 1.0)) * REFILL_SECONDS)


static func _add(questions: float) -> void:
	_settle()
	_tokens = minf(float(CAPACITY), _tokens + questions)
	_save()


## Refills from the time passed since it was last brought up to date, rather
## than on a timer, so it keeps counting through level changes, scene
## transitions and time with the game closed. The system clock, not ticks,
## since ticks start over with the game.
static func _settle() -> void:
	if not _loaded:
		_load()
	var now := Time.get_unix_time_from_system()
	if _stamp >= 0.0:
		# A clock set back gives nothing, rather than taking questions away.
		_tokens = minf(float(CAPACITY), _tokens + maxf(0.0, now - _stamp) / REFILL_SECONDS)
	_stamp = now


## Best-effort, like Progress: with no readable save, the pool starts full.
static func _load() -> void:
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("HintPool: could not read %s (error %d). Starting with a full pool." % [SAVE_PATH, err])
		return

	# Defaults that are not null: ConfigFile prints an error for a missing key
	# when the default is null.
	var questions: Variant = cfg.get_value("pool", "questions", -1.0)
	var updated_at: Variant = cfg.get_value("pool", "updated_at", -1)
	if not _is_number(questions) or not _is_number(updated_at) or questions < 0 or updated_at <= 0:
		push_warning("HintPool: %s holds no readable pool. Starting with a full pool." % SAVE_PATH)
		return
	_tokens = clampf(float(questions), 0.0, float(CAPACITY))
	_stamp = float(updated_at)


## Only when the pool changes other than by the clock: the clock's part is
## worked out again from the saved time.
static func _save() -> void:
	if not _disk_available:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("pool", "questions", _tokens)
	# Whole seconds, so the time is written exactly.
	cfg.set_value("pool", "updated_at", int(_stamp))
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		# Said once, as Progress does: a machine that can't write user:// fails
		# every save.
		_disk_available = false
		push_warning(
			"HintPool: cannot write %s (error %d). The pool will last this session only."
			% [SAVE_PATH, err]
		)


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
