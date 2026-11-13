extends Node
## The level being played, and the clock a running program keeps.

## The testing room the EYOW code opens. It isn't in the LevelCatalog, so it
## has no slot, no grid tile and no stars.
const SANDBOX_SCENE := "res://level/levels/sandbox.tscn"
const SANDBOX_ID := &"sandbox"

var level: Level
var level_scene: PackedScene
var level_id := &""
## A random id per launch, so the relay can tell sessions apart.
var session_id := Crypto.new().generate_random_bytes(8).hex_encode()


## Opens `entry`'s level in the puzzle screen.
func play(entry: LevelEntry) -> void:
	level_scene = entry.scene
	level_id = entry.id
	Transition.change_scene(Core.PUZZLE)


## Opens the sandbox: every block, and a room with the robot, a list, a
## dictionary, a text file and a terminal.
func play_sandbox() -> void:
	var entry := LevelEntry.new()
	entry.id = SANDBOX_ID
	entry.title = "Sandbox"
	entry.scene = load(SANDBOX_SCENE) as PackedScene
	entry.counts_for_progress = false
	play(entry)


## Waits `seconds` of running time: the wait stands still while the program is
## paused, and ends early when the program is stopped.
func sleep(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not Interpreter.interrupted:
		await get_tree().process_frame
		if not Interpreter.is_paused:
			remaining -= get_process_delta_time()
