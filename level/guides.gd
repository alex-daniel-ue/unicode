## The guides ("dimmed tutorials"): short runs of pages shown over the puzzle
## when a level opens with something new in it, and again from the pause menu.
## TutorialOverlay shows them; this says what they are.
##
## Kept in code rather than in scene files on purpose. The first tour kept its
## behaviour in exported properties on step nodes, and the editor dropped those
## from the scene twice (a save while a script wasn't loaded), each time leaving
## a tour that dimmed everything and swallowed the click it asked for.
##
## Write for a first-year who reads English as a second language and skims: a
## picture first, then one or two plain sentences, and never the answer. Plain
## is not short. Use whole sentences with the small words in them ("that",
## "of", "in"), one idea a sentence, and the same words every time: red flag,
## bottle, list, value, index. Never count on the student remembering the last
## level; say it again, or show it.
class_name Guides
extends RefCounted

## What moves a page on.
enum Advance {
	NEXT,               ## the card's button
	BLOCK_PLACED,       ## a block dropped into a mouth (begin, while, ...)
	BLOCK_TRASHED,      ## a block thrown away, by dragging or by Trash all
	RUN_STARTED,        ## Play started a run
	RUN_FINISHED,       ## the run ended, whatever the outcome
	ROOM_COMPLETED,     ## one room of a multi-room level was solved
	LEVEL_COMPLETED,    ## the level was solved
	ERROR_RAISED,       ## a block raised an error
	MESSAGE_SENT,       ## the student sent the assistant a message
	ASSISTANT_REPLIED,  ## the assistant answered
	MENU_OPENED,        ## the pause menu opened
	MENU_CLOSED,        ## the pause menu closed
	PANEL_CLOSED,       ## a side panel was closed with its button
	PANEL_OPENED,       ## a side panel was opened with its button
	VIEW_FRAMED,        ## the reframe button was pressed
}

const LEFT := "UserInterface/SideMenuLeft/Panel"
const LEFT_BUTTONS := "UserInterface/SideMenuLeft/ButtonContainer/"
const RIGHT_BUTTONS := "UserInterface/SideMenuRight/ButtonContainer/"
const ROOM := "UserInterface/SideMenuRight/Panel"
const WORKSPACE := "UserInterface/MiddleSpace"
const TOOLBOX := LEFT + "/PuzzleToolbox"
const GRAPHICS := "res://puzzle/ui/tutorial/graphics/"

## The programs of the worked examples, for the level after each, where the
## student builds it: "this is what you watched". BlockPicture's program format.
const IT_0A_PROGRAM := '[["move"], ["move"], ["if", ["not", ["ahead", "puddle"]], {"body": [["move"]]}]]'
const AR_1_PROGRAM := '[["moven", ["index", 0, ["list", "route"]]], ["turn", "left"], ["moven", ["index", 1, ["list", "route"]]]]'

## The picture (GuideGraphics) on the page of a block that the robot or a list
## does something with, by the block's data name. Blocks that are only
## programming (if, while, a variable) are explained by their note alone.
const BLOCK_PICTURES := {
	"MoveBlock": "move",
	"MoveTilesBlock": "move_n",
	"TurnBlock": "turn",
	"AheadIsBlock": "ahead_is",
	"LengthOfBlock": "length_of",
	"SetItemBlock": "set_index",
	"AppendBlock": "append",
	"InBlock": "contains",
	"ForEachBlock": "for_each",
}

## Page keys, all optional:
##   title, text   Short. The text is one or two sentences at most.
##   picture       A GuideGraphics picture, by name ("ahead_is").
##   video         An .ogv clip, looped and silent.
##   graphic       A .tscn (instanced) or an image.
##   program       A small program under a begin block (BlockPicture.program).
##   block         A BlockData path, shown as a picture of the block, with
##   block_values  its slots filled ("list:route" puts route's name block in).
##   targets       What stays lit and clickable. Paths from the Puzzle root;
##                 "block:Name" for a toolbox block by data name; "level:Path"
##                 for a node in the level, such as a list's board.
##   arrow         Which target the arrow from the card points at ("" for no
##                 arrow). Unset, it is the smallest target, if that is small.
##   focus         A side panel tab to open first (a path, like TOOLBOX).
##   advance       What moves the page on (Advance). NEXT unless given.
##   only          For BLOCK_PLACED and BLOCK_TRASHED: that block's data name.
##   button        The button's text. A page that waits for an action shows no
##                 button unless it names one.
##   dim           false leaves the screen undimmed.
##   block_input   true swallows every click, targets included ("just watch").
##   card          "top" keeps the card at the top, clear of a popup.
const SETS := {
	&"first_steps": [
		{title = "Welcome!", text = "You will tell a robot what to do. You do this with blocks. First, let's look around.",
			button = "Start"},
		{title = "The room", text = "This is the room of the robot. Your goal is to get the robot to the red flag.",
			targets = [ROOM]},
		{title = "Look around", text = "Drag the room to move it. Scroll to zoom in and out. Then press this button to put the room back.",
			targets = [ROOM, RIGHT_BUTTONS + "FrameButton"], advance = Advance.VIEW_FRAMED},
		{title = "Need more space?", text = "This button hides the room. Press the button now.",
			targets = [RIGHT_BUTTONS + "EnvironmentButton"], advance = Advance.PANEL_CLOSED},
		{title = "Bring it back", text = "Press the same button again to show the room.",
			targets = [RIGHT_BUTTONS + "EnvironmentButton"], advance = Advance.PANEL_OPENED},
		{title = "Your task", text = "The task of every level is here. Read the task before you start.",
			focus = LEFT + "/PuzzleInformation", targets = [LEFT, LEFT_BUTTONS + "InfoMenuButton"]},
		{title = "Your blocks", text = "The blocks that you can use are here, in the toolbox.",
			focus = TOOLBOX, targets = [LEFT, LEFT_BUTTONS + "ToolboxMenuButton"]},
		{title = "Place a block", text = "Drag the move forward block. Drop it on the begin block to attach it.",
			video = GRAPHICS + "place_solid_card.ogv",
			focus = TOOLBOX, targets = [LEFT, WORKSPACE, "block:MoveBlock", "block:BeginBlock"], arrow = "block:MoveBlock",
			advance = Advance.BLOCK_PLACED, only = "MoveBlock"},
		{title = "Throw it away", text = "Drag the move forward block onto the trash can. This throws the block away.",
			targets = [LEFT_BUTTONS + "TrashButton", WORKSPACE], advance = Advance.BLOCK_TRASHED, only = "MoveBlock"},
		{title = "Put it back", text = "Attach the move forward block to the begin block again. It should look like this.",
			program = '[["move"]]',
			focus = TOOLBOX, targets = [LEFT, WORKSPACE, "block:MoveBlock", "block:BeginBlock"], arrow = "block:MoveBlock",
			advance = Advance.BLOCK_PLACED, only = "MoveBlock"},
		{title = "The menu", text = "This button opens the menu. You can also press the Esc key. Open the menu now.",
			targets = [RIGHT_BUTTONS + "MenuButton"], advance = Advance.MENU_OPENED},
		{title = "The menu", text = "In the menu, you can go back to the levels, or see a tutorial again. Press Resume to close the menu.",
			dim = false, card = "top", advance = Advance.MENU_CLOSED},
		{title = "Run it", text = "Press Play to run your blocks. Press the X to stop them.",
			targets = [RIGHT_BUTTONS + "PlayButton", RIGHT_BUTTONS + "StopButton"], arrow = RIGHT_BUTTONS + "PlayButton",
			advance = Advance.RUN_STARTED},
		{title = "Watch", text = "Watch the robot. It does what your blocks say, in order.",
			dim = false, block_input = true, card = "top", advance = Advance.RUN_FINISHED},
	],
	&"rooms": [
		{title = "Two rooms", text = "This level has two rooms. Your program runs in Room 1 first. Then the same program runs again in Room 2.",
			targets = [ROOM, "level:Visuals/Room1Label", "level:Visuals/Room2Label"], arrow = "level:Visuals/Room1Label"},
	],
	&"watch_rooms": [
		{title = "Watch", text = "This program runs by itself. Watch the robot in Room 1, and then in Room 2.",
			targets = [ROOM], button = "Watch it run"},
	],
	&"rebuild_it": [
		{title = "The last program", text = "This is the program from the last level. It ran by itself. Now you build it.",
			program = IT_0A_PROGRAM, button = "Got it"},
		{title = "Blocks in slots", text = "Some blocks go into a slot of another block. Drag the block onto the empty slot. Drop it there to attach it.",
			video = GRAPHICS + "place_socket_card.ogv", button = "Got it"},
	],
	&"assistant": [
		{title = "Stuck? Ask for help", text = "Tell the assistant what you expected, and what happened. It gives you hints. It does not give you the answer.",
			focus = LEFT + "/AIAssistant", targets = [LEFT, LEFT_BUTTONS + "AIAssistantMenuButton"], button = "Got it"},
	],
	&"variables": [
		{title = "Your variables", text = "While your program runs, this tab shows every variable and its value.",
			focus = LEFT + "/VariableWatcher", targets = [LEFT, LEFT_BUTTONS + "VariableWatcherMenuButton"]},
		{title = "Answers on blocks", text = "Some blocks work out an answer. While your program runs, the answer shows in a small tag on the block.",
			graphic = GRAPHICS + "answer_tag.tscn", button = "Got it"},
	],
	&"lists": [
		{title = "This is a list", text = "A list can contain many values in order. This list has the name route.",
			graphic = GRAPHICS + "list_parts.tscn", targets = ["level:Visuals/Lists/Room1/route"]},
		{title = "Index", text = "Each value in a list has an index. The index is the small number under the value. The first index is 0.",
			graphic = GRAPHICS + "list_index.tscn", targets = ["level:Visuals/Lists/Room1/route"]},
		{title = "index ... of ...", text = "The index of block gives you the value at an index of a list.",
			graphic = GRAPHICS + "item_of.tscn", focus = TOOLBOX, targets = ["block:ItemOfBlock"]},
	],
	&"watch_list": [
		{title = "Watch", text = "The robot reads a value from the list. Then it moves that far. Watch it run.",
			button = "Watch it run"},
	],
	&"rebuild_list": [
		{title = "The last program", text = "This is the program from the last level. It ran by itself. Now you build it. Each room has a different list.",
			program = AR_1_PROGRAM, button = "Got it"},
	],
	&"list_names": [
		{title = "The name block of a list", text = "Each list has a name block. Drop the name block into the list slot of a block.",
			graphic = GRAPHICS + "name_block.tscn", focus = TOOLBOX, targets = ["block:List_route", "block:ItemOfBlock"], button = "Got it"},
	],
	&"goal_marks": [
		{title = "What it should be", text = "The small green number shows the value that the box should have at the end.",
			graphic = GRAPHICS + "goal_corner.tscn", targets = ["level:Visuals/Lists/Room1/lockers"]},
		{title = "Right or wrong?", text = "When your program changes a value, the box turns green if the value is right. The box turns red if the value is wrong.",
			graphic = GRAPHICS + "goal_checked.tscn", targets = ["level:Visuals/Lists/Room1/lockers"], button = "Got it"},
	],
	&"empty_list": [
		{title = "An empty list", text = "This list starts empty. The faded values show what the list should have at the end.",
			graphic = GRAPHICS + "goal_faded.tscn", targets = ["level:Visuals/Lists/Room1/passed"], button = "Got it"},
	],
}

## Which sets a level gets, in order, keyed by scene file name. "blocks" stands
## for a page per new block, made from the level's own description, except a
## block that a page before it already covers. A level not listed gets just
## those, if it has any new blocks.
const LEVELS := {
	"tutorial_1": [&"first_steps"],
	"it_0a": [&"rooms", &"blocks", &"watch_rooms"],
	"it_0b": [&"rebuild_it"],
	"it_1": [&"blocks", &"assistant"],
	"it_4": [&"blocks", &"variables"],
	"ar_1": [&"lists", &"blocks", &"watch_list"],
	"ar_2": [&"rebuild_list", &"list_names", &"blocks"],
	"ar_7": [&"blocks", &"goal_marks"],
	"ar_8": [&"empty_list", &"blocks"],
}


static func pages_for(level: Level) -> Array:
	if level == null or level.scene_file_path.is_empty():
		return []
	var key := level.scene_file_path.get_file().get_basename()
	var pages: Array = []
	for item: StringName in LEVELS.get(key, [&"blocks"]):
		if item == &"blocks":
			pages.append_array(block_pages(level, _covered(pages)))
		elif SETS.has(item):
			pages.append_array(SETS[item])
		else:
			push_warning("Guides: level '%s' names a set '%s' that doesn't exist." % [key, item])
	return pages

## A page per block the level introduces, from its description: the block's
## name, a picture of what it does when there is one, the block, its note, and
## the block lit in the toolbox. Blocks named in `skip` get none.
static func block_pages(level: Level, skip: PackedStringArray = []) -> Array:
	var description := level.description
	if description == null:
		return []
	# A worked example has nothing in its toolbox; its new blocks are pointed
	# out in the program on the canvas, with the toolbox left shut.
	var toolbox_names: PackedStringArray = []
	for data in level.get_block_data():
		if data != null:
			toolbox_names.append(data.name)
	var pages: Array = []
	for i in description.blocks.size():
		var data := description.blocks[i]
		if data == null or data.name in skip:
			continue
		var values: PackedStringArray = []
		if i < description.block_values.size():
			values = description.block_values[i].split(",", true)
		var page := {
			title = data.display_name(),
			block = data,
			block_values = values,
			text = description.block_notes[i] if i < description.block_notes.size() else "",
			targets = ["block:" + data.name],
		}
		if data.name in toolbox_names:
			page.focus = TOOLBOX
		if BLOCK_PICTURES.has(data.name):
			page.picture = BLOCK_PICTURES[data.name]
		pages.append(page)
	return pages

## The blocks that `pages` already light up in the toolbox.
static func _covered(pages: Array) -> PackedStringArray:
	var names: PackedStringArray = []
	for page: Dictionary in pages:
		for path: String in page.get("targets", []):
			if path.begins_with("block:"):
				names.append(path.trim_prefix("block:"))
	return names
