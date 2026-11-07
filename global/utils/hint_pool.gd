class_name HintPool
extends RefCounted
## The assistant's question budget: a pool that refills, shared by every level.
##
## CAPACITY questions to start, one more every REFILL_SECONDS, never above
## CAPACITY. Kept up, that is one question a minute: enough to get unstuck, too
## few to have the assistant work a level out, and a student who asks twice
## after a long think isn't punished for it.
##
## Shared across levels, since a per-level cap resets by opening the next level.
## Held in memory only, never written to disk or to the study's data, so
## restarting the game refills it.
##
## The win card's comment doesn't draw from it (it is not a hint), and a request
## that never reached the model is given back (a dead relay is not the
## student's fault).

const CAPACITY := 10
const REFILL_SECONDS := 60.0

static var _tokens := float(CAPACITY)
static var _stamp_ms := -1


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
	return true


## Gives back a question whose request never produced a hint.
static func refund() -> void:
	_settle()
	_tokens = minf(float(CAPACITY), _tokens + 1.0)


## Seconds until the next whole question comes back. 0 when the pool is full.
static func seconds_to_next() -> int:
	_settle()
	if _tokens >= float(CAPACITY):
		return 0
	return ceili((1.0 - fposmod(_tokens, 1.0)) * REFILL_SECONDS)


## Refills from the time passed since it was last asked, rather than on a timer,
## so it keeps counting through level changes and scene transitions.
static func _settle() -> void:
	var now := Time.get_ticks_msec()
	if _stamp_ms >= 0:
		var elapsed := (now - _stamp_ms) / 1000.0
		_tokens = minf(float(CAPACITY), _tokens + elapsed / REFILL_SECONDS)
	_stamp_ms = now
