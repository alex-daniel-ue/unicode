extends Node
## Sound effects, from a small pool of players so they can overlap.
##
## Buttons click only when they're in the "sfx_click" group (set in their
## scenes): the room, view, speed, Play, Stop, menu and trash buttons, and the
## menus' own. The ones pressed all the time (a guide's Next, the side panel
## tabs) stay quiet, and so does anything that opens a level, since the level's
## own start sound follows it.

const CLICK_GROUP := &"sfx_click"
const BUTTON_CLICK := preload("res://audio/button_click.mp3")
const LEVEL_START := preload("res://audio/level_start.mp3")
const NEXT_ROOM := preload("res://audio/next_room.mp3")
const SUCCESS := preload("res://audio/success.mp3")
const FAIL := preload("res://audio/fail.mp3")
const BLOCK_PICKED_UP := preload("res://audio/block_picked_up.mp3")
const BLOCK_DROP := preload("res://audio/block_drop.mp3")
const BLOCK_TRASH := preload("res://audio/block_trash.mp3")
## One of these as each block runs: F#5, A5, B5 and D6, notes of the D major
## pentatonic, so any two that overlap in a fast run still sound good together;
## the level's start sound is G5, in the same family of keys. Tuned to their
## names by tools/audio/balance.py; the originals are in audio/source/.
const BLOCK_PULSES: Array[AudioStream] = [
	preload("res://audio/block_pulse_f#5.mp3"),
	preload("res://audio/block_pulse_a5.mp3"),
	preload("res://audio/block_pulse_b5.mp3"),
	preload("res://audio/block_pulse_d6.mp3"),
]
## Each sound's gain, so they sit together: measured by tools/audio/balance.py
## (the loudest 100 ms of each, K-weighted, the way LUFS measures loudness)
## against a target for each kind of sound. The win and the fail loudest, then
## a level opening and the next room, then the clicks and block sounds, and the
## pulses under everything, since one comes with every block. Rerun the tool
## after changing a sound, and paste its table here.
const GAIN_DB := {
	"block_drop": -14.7,
	"block_picked_up": -6.2,
	"block_pulse_a5": -26.2,
	"block_pulse_b5": -26.4,
	"block_pulse_d6": -26.6,
	"block_pulse_f#5": -25.9,
	"block_trash": -4.5,
	"button_click": -29.3,
	"fail": -3.7,
	"level_start": -11.1,
	"next_room": -16.5,
	"success": -6.1,
}
## Every block gets its pulse sound, however fast the run. Closer together than
## this, each is a little quieter, down to PULSE_FAST_DB at the fastest, so a
## fast run is a quick patter instead of a buzz.
const PULSE_FULL_GAP_MS := 160.0
const PULSE_FAST_DB := -9.0
## Pulses take turns on their own players, so a new one never waits for a free
## player in the pool and only ever cuts off the one from three pulses ago.
const PULSE_VOICES := 3
const POOL_SIZE := 16
const VOLUME := 0.8

var _pool: Array[AudioStreamPlayer] = []
var _pulse_voices: Array[AudioStreamPlayer] = []
var _pulse_turn := 0
var _last_pulse_ms := -100000
var _last_pulse: AudioStream


## The balancing gain for `sfx`, by its file name (GAIN_DB).
static func gain_of(sfx: AudioStream) -> float:
	return GAIN_DB.get(sfx.resource_path.get_file().get_basename(), 0.0)


func _ready() -> void:
	for i in POOL_SIZE:
		_pool.append(_new_player())
	for i in PULSE_VOICES:
		_pulse_voices.append(_new_player())
	get_tree().node_added.connect(_on_node_added)


func play(sfx: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	if not sfx:
		return
	for player in _pool:
		if not player.playing:
			player.stream = sfx
			player.pitch_scale = pitch
			player.volume_db = linear_to_db(VOLUME) + gain_of(sfx) + volume_db
			player.play()
			break


## A block lighting up as the program runs: one of the notes, never the same
## one twice in a row.
func play_pulse() -> void:
	var now := Time.get_ticks_msec()
	var gap := float(now - _last_pulse_ms)
	_last_pulse_ms = now
	var choices := BLOCK_PULSES.filter(func(s: AudioStream) -> bool: return s != _last_pulse)
	_last_pulse = choices.pick_random()
	var player := _pulse_voices[_pulse_turn]
	_pulse_turn = (_pulse_turn + 1) % _pulse_voices.size()
	var quieter := lerpf(PULSE_FAST_DB, 0.0, clampf(gap / PULSE_FULL_GAP_MS, 0.0, 1.0))
	player.stream = _last_pulse
	player.volume_db = linear_to_db(VOLUME) + gain_of(_last_pulse) + quieter
	player.play()


func play_click() -> void:
	play(BUTTON_CLICK)


func _new_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.volume_db = linear_to_db(VOLUME)
	add_child(player)
	return player


func _on_node_added(node: Node) -> void:
	# A button that leaves the tree and comes back (a reparent) is added again.
	if node is BaseButton and node.is_in_group(CLICK_GROUP) and not (node as BaseButton).pressed.is_connected(play_click):
		(node as BaseButton).pressed.connect(play_click)
