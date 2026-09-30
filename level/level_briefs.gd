## Fallback copy for every level's brief, keyed by scene file name.
##
## LevelDescription reads its scene fields first and fills any that are empty
## from here. The scene fields are exported properties on a non-@tool script,
## and the editor has twice saved scenes without such values (the tutorial
## steps lost theirs the same way), which in the export showed up as block
## pictures with no text under them. Keep this in step with the scenes.
class_name LevelBriefs
extends RefCounted

const BRIEFS := {
	"tutorial_1": {
		"title": "First steps",
		"mission": "Get the robot onto the red flag.",
		"blocks": ["res://level/objects/entities/robot/blocks/move.tres"],
		"block_notes": ["Your only block for now. It moves the robot one tile the way it's facing."],
	},
	"it_0a": {
		"title": "Read it first",
		"mission": "This program is already written. Watch it run in Room 1, then again in Room 2, and work out why the robot stops in a different place.",
		"twist": "But it's the same program in both rooms. The only difference is what's in front of the robot.",
		"tip": "It runs by itself when the level opens. Press Play to watch it again.",
		"rooms": ["Finish on the flag.", "Stop right before the puddle."],
		"blocks": ["res://level/objects/entities/robot/blocks/ahead_is.tres", "res://puzzle/blocks/socket/not.tres", "res://puzzle/blocks/control flow/if.tres"],
		"block_notes": ["Here it looks for the puddle. It checks the one tile in front of the robot and gives True or False.", "Flips the answer, so True becomes False and False becomes True. It lets a program ask the opposite question.", "The last step only happens when its condition is True. An if runs the blocks inside it only when its condition is True."],
		"block_values": ["puddle", "", ""],
		"show_stars": false,
	},
	"it_0b": {
		"title": "Rebuild it",
		"mission": "Build last level's program yourself. It runs in Room 1, then again in Room 2.",
		"twist": "But the canvas starts empty this time.",
		"rooms": ["Finish on the flag.", "Stop right before the puddle, not in it."],
	},
	"it_1": {
		"title": "Until the wall",
		"mission": "One program runs in all three rooms. Get the robot onto the flag in each one.",
		"twist": "But the hallways are all different lengths, and the same program has to handle every one.",
		"rooms": ["A short hallway.", "A longer hallway.", "The longest hallway."],
		"blocks": ["res://puzzle/blocks/control flow/while.tres", "res://level/objects/entities/robot/blocks/ahead_is.tres", "res://puzzle/blocks/socket/not.tres"],
		"block_notes": ["It's already on the canvas; you decide what it checks. A while repeats the blocks inside it for as long as its condition is True.", "The robot's eyes. It checks the one tile in front: a wall (blocked), the flag (destination), or a puddle, and gives True or False.", "Flips True into False and False into True. It lets you ask the opposite question."],
	},
	"it_2": {
		"title": "Until you see it",
		"mission": "One program, three rooms. Finish on the flag in every room.",
		"twist": "But the flags aren't against the wall anymore. The robot has to stop on the flag, not at the end of the hall.",
		"rooms": ["The flag is partway down the hall.", "The flag is further along.", "The flag is somewhere else again."],
		"blocks": ["res://level/objects/entities/robot/blocks/ahead_is.tres"],
		"block_notes": ["It can look for the flag too: pick destination from its list. Like before, it only checks the one tile in front of the robot."],
		"block_values": ["destination"],
	},
	"it_3": {
		"title": "Around the bends",
		"mission": "One program, three rooms with corners. Finish on the flag in every room.",
		"twist": "But every room turns a different number of times, so no fixed list of moves works for all three.",
		"rooms": ["One bend.", "Two bends.", "A winding path."],
		"blocks": ["res://puzzle/blocks/control flow/if.tres", "res://puzzle/blocks/control flow/else.tres", "res://level/objects/entities/robot/blocks/turn.tres"],
		"block_notes": ["Lets the robot make a decision at every step. It runs the blocks inside it only when its condition is True.", "Goes right under an if and runs only when that if didn't. Together they make an either-or choice.", "Turns the robot left, right, or back (all the way around). Turning doesn't move it off its tile."],
	},
	"it_4": {
		"title": "Count the desks",
		"mission": "Stop the robot exactly on the flag.",
		"twist": "But there's only one move forward block, and it's already on the canvas.",
		"tip": "Open the Variables tab to watch your variables change while the program runs.",
		"blocks": ["res://puzzle/blocks/generic/initialize.tres", "res://puzzle/blocks/generic/increment.tres", "res://puzzle/blocks/socket/comparison.tres"],
		"block_notes": ["Makes a new variable and gives it a starting value. A variable is a named box that holds a value.", "Adds 1 to a variable. Each time it runs, the number goes up by one.", "Compares two values, like 2 < 5, and gives True or False. That makes it usable as a loop's condition."],
	},
	"it_5": {
		"title": "One block instead of three",
		"mission": "Get the robot around the corner and onto the flag.",
		"twist": "But there's no while and no variables this time. The for block is the only way to repeat.",
		"blocks": ["res://puzzle/blocks/control flow/for_int.tres"],
		"block_notes": ["Counts a variable from a start to an end, end included, and runs its blocks once per count. From 1 to 4 is four passes, like range(1, 5) in Python."],
	},
	"it_6": {
		"title": "A pattern, not a step",
		"mission": "Climb the staircase of desks and finish on the flag.",
		"twist": "But the for loop is already placed, and it's the only loop you get.",
		"tip": "Everything inside a loop repeats together, in order, on every pass.",
	},
	"it_7": {
		"title": "Aisle by aisle",
		"mission": "Drive down every aisle to pick up all the pens, then finish on the flag. Driving over a pen picks it up.",
		"twist": "But the outer loop is already placed, one pass per aisle. What goes inside it is up to you.",
		"tip": "A loop can hold another loop: the inner one runs all the way through on every pass of the outer one. Loops inside each other need different variable names.",
	},
	"it_8": {
		"title": "Every row is longer",
		"mission": "Pick up every pen, row by row, then finish on the flag.",
		"twist": "But every row of pens is longer than the one before it.",
		"tip": "A for loop's start and end can be variables, not only numbers.",
	},
	"it_9": {
		"title": "Two ways out",
		"mission": "One program, three rooms. In each room, stop on the flag or right before a puddle, whichever comes first.",
		"twist": "But the not block is missing this time.",
		"rooms": ["Finish on the flag.", "Stop right before the puddle.", "Finish on the flag."],
		"blocks": ["res://puzzle/blocks/control flow/break.tres", "res://puzzle/blocks/socket/boolean.tres"],
		"block_notes": ["Ends the loop it's inside, right away. The program carries on after the loop.", "A condition that is always True, or always False. A loop on True never stops by itself."],
	},
	"it_10": {
		"title": "Back to the question",
		"mission": "One program, three winding rooms. Finish on the flag in every room.",
		"twist": "But there's no else block this time.",
		"blocks": ["res://puzzle/blocks/control flow/continue.tres"],
		"block_notes": ["Skips the rest of the loop's blocks for this pass and goes straight back to the loop's condition. It's a loop's way of saying: check again."],
	},
	# Arrays. Generated alongside the scenes; keep the two in step.
	"ar_1": {
		"title": "Read the card",
		"mission": "One program, three rooms. The card on the wall gives the way to the flag: walk its first number of tiles, turn left, then walk its second number.",
		"twist": "But the card says something different in every room.",
		"rooms": ["A wide room.", "A tall room.", "A long, low room."],
		"blocks": ["res://puzzle/blocks/lists/item_of.tres", "res://level/objects/entities/robot/blocks/move_n.tres"],
		"block_notes": ["Here it reads one number off the card. It gives the item at a position in a list, and positions start at 0.", "Here the robot walks as far as a number says. It moves forward that many tiles, one at a time."],
		"tip": "In Python, item 0 of route is written route[0].",
	},
	"ar_2": {
		"title": "Count, then the last",
		"mission": "One program, three rooms. Walk one tile for every number on the card, turn left, then walk the card's last number to reach the flag.",
		"twist": "But every card holds a different number of numbers.",
		"rooms": ["Three numbers.", "Two numbers.", "Four numbers."],
		"blocks": ["res://puzzle/blocks/lists/length_of.tres", "res://puzzle/blocks/socket/arithmetic.tres"],
		"block_notes": ["Here it counts the numbers on the card. It gives how many items a list holds.", "Here it can work one number out from another. It does math with + - * / // and %, the way Python does."],
		"tip": "In Python, length of route is written len(route).",
	},
	"ar_3": {
		"title": "Every stop",
		"mission": "One program, three rooms. The card lists how far to drive before each left turn. Drive every stop in order, pick up the pens on the way, and finish on the flag.",
		"twist": "But every card has a different number of stops.",
		"rooms": ["A lap that ends where it starts.", "A spiral.", "A U-turn."],
		"tip": "UniCode's for counts up to and including its last number: from 0 to 3 is 0, 1, 2, 3. Python's range(0, 3) stops before the 3.",
	},
	"ar_4": {
		"title": "Every stop, again",
		"mission": "Last level's rooms. Drive every stop on the card in order, turning left after each one, pick up the pens, and finish on the flag.",
		"twist": "But there's no item of or length of this time.",
		"rooms": ["A lap that ends where it starts.", "A spiral.", "A U-turn."],
		"blocks": ["res://puzzle/blocks/control flow/for_each.tres"],
		"block_notes": ["Here it hands you each stop on the card, one at a time. A for each loop runs the blocks inside it once for every item, with its variable holding that item."],
		"tip": "Python has the same loop: for leg in route: runs once for every item in route.",
	},
	"ar_5": {
		"title": "There and back",
		"mission": "One program, three rooms. Drive the card's stops out to the pen, turning left after each, then drive the same way back to the flag where you started.",
		"twist": "But the way home is the same trip, backwards.",
		"rooms": ["A long way out.", "A winding way out.", "A short way out."],
		"tip": "A for loop can count down: from 3 to 0 at step -1 runs 3, 2, 1, 0.",
	},
	"ar_6": {
		"title": "Number the lockers",
		"mission": "One program, three rooms. Walk along the lockers and give each one its number, then finish on the flag just past the last locker.",
		"twist": "But locker numbers are for people, and people count from 1.",
		"rooms": ["Three lockers.", "Five lockers.", "Four lockers."],
		"blocks": ["res://puzzle/blocks/lists/set_item.tres"],
		"block_notes": ["Here it writes a number onto a locker. It changes the item at a position in a list, and that position has to exist already."],
		"tip": "In Python, set item 0 of lockers to 5 is written lockers[0] = 5.",
	},
	"ar_7": {
		"title": "Passing marks",
		"mission": "One program, three rooms. Put every passing score (75 or higher) from scores into passed, then walk one tile for each passing score to reach the flag.",
		"twist": "But scores is a tuple, and a tuple can't be changed.",
		"rooms": ["Five scores.", "Four scores.", "Six scores."],
		"blocks": ["res://puzzle/blocks/lists/append.tres"],
		"block_notes": ["Here it adds a passing score to the end of passed. It makes a list one item longer; a tuple can't grow."],
		"tip": "The brackets on a shelf say what it holds, the way Python writes it: [ ] is a list and ( ) is a tuple.",
	},
	"ar_8": {
		"title": "Tidy the shelf",
		"mission": "One program, three rooms. Copy bags onto tidy, leaving out any bag that's the same as the one right before it. Then walk one tile for each bag on tidy.",
		"twist": "But a number can come back later, and when it does, it stays.",
		"rooms": ["Eight bags.", "Five bags.", "Four bags."],
		"tip": "!= means not equal. It's in the comparison block's list.",
	},
	"ar_9": {
		"title": "Here either day",
		"mission": "One program, three rooms. Put everyone who came on Monday or Tuesday into present, then walk one tile for each student in it.",
		"twist": "But some students came on both days.",
		"rooms": ["Three and three.", "Two and two.", "Four and two."],
		"blocks": ["res://puzzle/blocks/lists/add.tres"],
		"block_notes": ["Here it puts a student into present. It adds a value to a set, and a set keeps only one of each value."],
		"tip": "Curly brackets mean a set, as in Python: {1, 2, 3}. Python can join two sets in one step with |.",
	},
	"ar_10": {
		"title": "In all three",
		"mission": "One program, three rooms. Put every student who is in all three clubs into all_three, then walk one tile for each of them.",
		"twist": "But a student counts only if they're in chess, choir and coding.",
		"rooms": ["Four chess players.", "Two chess players.", "Three chess players."],
		"blocks": ["res://puzzle/blocks/lists/contains.tres", "res://puzzle/blocks/socket/and_or.tres"],
		"block_notes": ["Here it checks whether a student is in a club. It gives True if the value is anywhere in the list, tuple or set.", "Here it can ask about two clubs at once. and is True only when both sides are; or is True when either one is."],
		"tip": "Python can find what three sets share in one step: chess & choir & coding.",
	},
}


static func for_scene(scene_path: String) -> Dictionary:
	return BRIEFS.get(scene_path.get_file().get_basename(), {})
