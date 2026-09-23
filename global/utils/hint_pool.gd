class_name HintPool
extends RefCounted

## The assistant's message budget: a regenerating pool shared by every level.
##
## CAPACITY messages to start, one more every REFILL_SECONDS, never above
## CAPACITY. Sustained use is therefore one question a minute, which is enough
## to stay unstuck and too little to outsource a level to. The panel's concern
## was a student letting the assistant do the thinking; a pool caps the rate of
## that without punishing the student who asks twice in a row after a long think.
##
## Shared across levels on purpose: a per-level cap resets by opening the next
## level. Held in memory only, so it is never written to disk and never part of
## the study's data -- restarting the game refills it, which is honour-level in
## the same way the release gate in unicode.cfg is.
##
## The post-win summary does not draw from it (it is not a hint), and a request
## that never reached the model is refunded (a dead relay is not the student's
## fault).

const CAPACITY := 10
const REFILL_SECONDS := 60.0

static var _tokens := float(CAPACITY)
static var _stamp_ms := -1


## Whole messages available right now.
static func available() -> int:
	_settle()
	return floori(_tokens)


## Spends one message. False, and nothing spent, when the pool is empty.
static func take() -> bool:
	_settle()
	if _tokens < 1.0:
		return false
	_tokens -= 1.0
	return true


## Gives back a message whose request never produced a hint.
static func refund() -> void:
	_settle()
	_tokens = minf(float(CAPACITY), _tokens + 1.0)


## Seconds until the next whole message comes back. 0 when the pool is full.
static func seconds_to_next() -> int:
	_settle()
	if _tokens >= float(CAPACITY):
		return 0
	return ceili((1.0 - fposmod(_tokens, 1.0)) * REFILL_SECONDS)


## Regeneration is computed from elapsed time when asked, not ticked by a timer,
## so it keeps counting through level changes and scene transitions.
static func _settle() -> void:
	var now := Time.get_ticks_msec()
	if _stamp_ms >= 0:
		var elapsed := (now - _stamp_ms) / 1000.0
		_tokens = minf(float(CAPACITY), _tokens + elapsed / REFILL_SECONDS)
	_stamp_ms = now
