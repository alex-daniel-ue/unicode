class_name LevelBriefs
extends RefCounted
## A copy of every level's brief, keyed by scene file name.
##
## LevelDescription reads its scene fields first and fills any that are empty
## from here. The scene fields are exported properties on a script that isn't
## @tool, and the editor has saved scenes without such values, which in the
## export showed up as block pictures with no text under them. Keep this in step
## with the scenes.

const BRIEFS := {
	"tutorial_1": {
		"title": "First steps",
		"mission": "Get the robot to the green flag.",
		"blocks": ["res://level/objects/entities/robot/blocks/move.tres"],
		"block_notes": ["This block makes the robot step forward by one tile."],
	},
	"it_0a": {
		"title": "Read it first",
		"mission": "This program runs by itself in both rooms. Watch where the robot stops in each room.",
		"twist": "The program is the same in both rooms. Only the tile in front of the robot is different.",
		"tip": "Press Play to watch the program again.",
		"rooms": ["Stop on the green flag.", "Stop right before the puddle."],
		"blocks": ["res://level/objects/entities/robot/blocks/ahead_is.tres", "res://puzzle/blocks/socket/not.tres", "res://puzzle/blocks/control flow/if.tres"],
		"block_notes": ["This block checks the tile in front of the robot. It gives True or False.", "This block turns True into False, and False into True.", "This block runs the blocks inside it only when its condition is True."],
		"block_values": ["puddle", "", ""],
		"show_stars": false,
	},
	"it_0b": {
		"title": "Rebuild it",
		"mission": "Build the program from the last level. The program runs in Room 1. Then the same program runs again in Room 2.",
		"twist": "The canvas starts empty this time.",
		"rooms": ["Stop on the green flag.", "Stop right before the puddle. Do not step in it."],
	},
	"it_1": {
		"title": "Until the wall",
		"mission": "One program runs in all three rooms. Get the robot to the green flag in each room.",
		"twist": "Each hallway has a different length.",
		"rooms": ["A short hallway.", "A longer hallway.", "The longest hallway."],
		"blocks": ["res://puzzle/blocks/control flow/while.tres", "res://level/objects/entities/robot/blocks/ahead_is.tres", "res://puzzle/blocks/socket/not.tres"],
		"block_notes": ["This block repeats the blocks inside it while its condition is True.", "This block checks the tile in front of the robot. Is the tile blocked? Is it the green flag? Is it a puddle?", "This block turns True into False, and False into True."],
	},
	"it_2": {
		"title": "Until you see it",
		"mission": "One program runs in all three rooms. Stop the robot on the green flag in each room.",
		"twist": "The green flag is not at the end of the hallway anymore.",
		"rooms": ["The green flag is part of the way down the hallway.", "The green flag is further along.", "The green flag is in a different place again."],
		"blocks": ["res://level/objects/entities/robot/blocks/ahead_is.tres"],
		"block_notes": ["This block can also look for the green flag. Pick destination in the block."],
		"block_values": ["destination"],
	},
	"it_3": {
		"title": "Around the corners",
		"mission": "One program runs in all three rooms. Each room has corners. Get the robot to the green flag in each room.",
		"twist": "Each room turns a different number of times.",
		"rooms": ["One corner.", "Two corners.", "Three corners."],
		"blocks": ["res://puzzle/blocks/control flow/if.tres", "res://puzzle/blocks/control flow/else.tres", "res://level/objects/entities/robot/blocks/turn.tres"],
		"block_notes": ["This block runs the blocks inside it only when its condition is True.", "Put this block right under an If block. It runs only when the If block did not run.", "This block turns the robot left, right, or around."],
	},
	"it_4": {
		"title": "Count the desks",
		"mission": "Stop the robot right on the green flag.",
		"twist": "You have only one Step Forward block. It is already on the canvas.",
		"tip": "The Variables tab shows your variables while your program runs.",
		"blocks": ["res://puzzle/blocks/generic/initialize.tres", "res://puzzle/blocks/generic/increment.tres", "res://puzzle/blocks/socket/comparison.tres"],
		"block_notes": ["This block makes a variable. A variable is a name that holds a value.", "This block adds 1 to a variable.", "This block compares two values, like 2 < 5. It gives True or False."],
	},
	"it_5": {
		"title": "One block instead of three",
		"mission": "Get the robot around the corner and onto the green flag.",
		"twist": "There is no While block this time. The For block is the only way to repeat.",
		"blocks": ["res://puzzle/blocks/control flow/for_int.tres"],
		"block_notes": ["This block counts from a start number up to an end number. It runs its blocks for each number. It stops before the end number, so from 1 until 5 runs 1, 2, 3, 4."],
	},
	"it_6": {
		"title": "A pattern, not a step",
		"mission": "Climb the stairs of desks and stop on the green flag.",
		"twist": "The For block is already on the canvas. It is the only loop that you get.",
		"tip": "The blocks inside a loop repeat together, in order, on every pass.",
	},
	"it_7": {
		"title": "Around the room",
		"mission": "Go once around the room and collect every battery. Then stop on the green flag where you started.",
		"twist": "The outer loop is already on the canvas. It makes one pass for each side of the room. You decide what goes inside it.",
		"tip": "A loop can hold another loop. Give each loop a different variable name.",
	},
	"it_8": {
		"title": "Every side is longer",
		"mission": "Collect every battery. Then stop on the green flag. The first battery is 1 step away. Each stop after it is 1 step further.",
		"twist": "The outer loop is already on the canvas. It makes one pass for each side of the path. You decide what goes inside it.",
		"tip": "The end of a For block can be a variable. From 0 until 3 runs 3 times: 0, 1, 2.",
	},
	"it_9": {
		"title": "Two ways out",
		"mission": "One program runs in all three rooms. In each room, stop on the green flag or right before a puddle. Stop at the one that comes first.",
		"twist": "The Not block is missing this time.",
		"rooms": ["Stop right before the puddle.", "Stop on the green flag.", "Stop on the green flag."],
		"blocks": ["res://puzzle/blocks/control flow/break.tres", "res://puzzle/blocks/socket/boolean.tres"],
		"block_notes": ["This block ends the loop that it is in, right away.", "This block is always True, or always False."],
	},
	"it_10": {
		"title": "Back to the question",
		"mission": "One program runs in all three rooms. Each room has a winding path. Get the robot to the green flag in each room.",
		"twist": "There is no Else block this time.",
		"blocks": ["res://puzzle/blocks/control flow/continue.tres"],
		"block_notes": ["This block skips the rest of this pass. Then the loop checks its condition again."],
	},
	# Arrays. Generated alongside the scenes; keep the two in step.
	"ar_t2": {
		"title": "Read a list",
		"mission": "Stop the robot on the green flag in each room. The flag is as far away as the third value in the list.",
		"twist": "Each room has a different list.",
		"rooms": ["A list with three values.", "A list with four values."],
		"blocks": ["res://level/objects/entities/robot/blocks/move_n.tres", "res://puzzle/blocks/lists/list_reporter.tres", "res://puzzle/blocks/lists/item_of.tres"],
		"block_notes": ["This block makes the robot step forward that many times. A number, or the answer of another block, goes into it.", "This is the name block of a list. Drop it into a list slot.", "This block gives you the value at an index of a list. The first index is 0."],
		"block_values": ["", "", ",list:route"],
		"tip": "In Python, index 0 of route is written as `route[0]`.",
	},
	"ar_t3": {
		"title": "How long is a list?",
		"mission": "Before the turn, move as far as the number of values in the list. After the turn, move as far as the first value in the list.",
		"twist": "Each room has a list of a different length.",
		"rooms": ["A short list.", "A longer list."],
		"blocks": ["res://puzzle/blocks/lists/length_of.tres"],
		"block_notes": ["This block counts the values in a list. A list with 4 values has indexes 0 to 3."],
		"block_values": ["list:route"],
		"tip": "In Python, length of route is written as `len(route)`.",
	},
	"ar_3": {
		"title": "Last index, last value",
		"mission": "Move as far as the last value in the list.",
		"twist": "Each list has a different length.",
		"rooms": ["A list with three values.", "A list with four values."],
		"blocks": ["res://puzzle/blocks/socket/arithmetic.tres"],
		"block_notes": ["This block does math, like 3 + 1. Pick the sign in the middle. Either side can take a number, or the answer of another block."],
		"tip": "The Math block can use the answer of another block. In Python: `len(route) + 1`.",
	},
	"ar_4": {
		"title": "Every stop",
		"mission": "Each value in the list is how far to move before the next left turn. Collect every battery on the way to the green flag.",
		"twist": "Both lists have 3 values, but not the same ones.",
		"rooms": ["A U-turn.", "Two corners, then one step."],
		"tip": "The For block stops before its end number, like `range(0, 3)` in Python, which gives 0, 1, 2.",
	},
	"ar_5": {
		"title": "Every stop, again",
		"mission": "Each value in the list is how far to move before the next left turn. Collect every battery on the way to the green flag.",
		"twist": "The lists are longer now, and there is no Index Of block.",
		"rooms": ["A lap.", "A U-turn, then one more step."],
		"blocks": ["res://puzzle/blocks/control flow/for_each.tres"],
		"block_notes": ["This block runs its blocks once for each value in a list. The box that it is on lights up."],
		"block_values": ["steps,list:route"],
		"tip": "In Python: `for steps in route:`",
	},
	"ar_6": {
		"title": "Last to first",
		"mission": "This list is in reverse order. Its last value is the first move. Each value is how far to move before the next left turn. Collect every battery on the way to the green flag.",
		"twist": "For Each goes from the first value to the last.",
		"rooms": ["Three stops.", "Four stops."],
		"tip": "The For block can count down. Give it a step of -1. It still stops before its end number.",
	},
	"ar_7": {
		"title": "Number the lockers",
		"mission": "Give each locker its number.",
		"twist": "People count lockers from 1, not from 0.",
		"rooms": ["Three lockers.", "Five lockers.", "Four lockers."],
		"blocks": ["res://puzzle/blocks/lists/set_item.tres"],
		"block_notes": ["This block changes the value at an index of a list."],
		"block_values": ["0,list:lockers,1"],
		"tip": "In Python: `lockers[0] = 1`",
	},
	"ar_8": {
		"title": "Passing marks",
		"mission": "Copy every score of 75 or more into the passed list. Keep the scores in the same order.",
		"twist": "The passed list starts empty.",
		"rooms": ["Five scores.", "Four scores.", "Six scores."],
		"blocks": ["res://puzzle/blocks/lists/append.tres"],
		"block_notes": ["This block adds a value to the end of a list."],
		"block_values": ["82,list:passed"],
		"tip": "In Python: `passed.append(s)`",
	},
	"ar_10": {
		"title": "In both",
		"mission": "Find every student who is in both chess and choir. Put each of them into the both list.",
		"twist": "Some rooms have no one in both.",
		"rooms": ["Four students in chess.", "Two students in chess.", "Three students in chess."],
		"blocks": ["res://puzzle/blocks/lists/contains.tres"],
		"block_notes": ["This block is True when the value is somewhere in the list."],
		"block_values": ["2,list:choir"],
		"tip": "In Python: `s in choir`",
	},
	"ar_11": {
		"title": "Here either day",
		"mission": "The monday list has the students who came on Monday. The tuesday list has the students who came on Tuesday. Put every student who came on either day into the present list, and put each student in only once.",
		"twist": "Some students came on both days.",
		"rooms": ["Three on Monday, three on Tuesday.", "Two on Monday, two on Tuesday.", "Four on Monday, two on Tuesday."],
		"tip": "The Not block turns True into False, and False into True.",
	},
}


## The brief for the level at `scene_path`, or an empty Dictionary.
static func for_scene(scene_path: String) -> Dictionary:
	var key := scene_path.get_file().get_basename()
	# The generated modules' briefs live in their own table (module_briefs.gd).
	return BRIEFS.get(key, ModuleBriefs.BRIEFS.get(key, {}))
