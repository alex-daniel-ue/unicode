## The guides ("dimmed tutorials"): short runs of pages shown over the puzzle
## when a level opens with something new in it, and again from the pause menu.
## TutorialOverlay shows them; this says what they are.
##
## Kept in code rather than in scene files on purpose. The first tour kept its
## behaviour in exported properties on step nodes, and the editor dropped those
## from the scene twice (a save while a script wasn't loaded), each time leaving
## a tour that dimmed everything and swallowed the click it asked for.
##
## Write for a first-year who reads English as a second language and is in a
## hurry: a picture first, then one or two short sentences, and never the answer.
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

## Page keys, all optional:
##   title, text   Short. The text is one or two sentences at most.
##   graphic       A .tscn (instanced) or an image, shown above the text.
##   block         A BlockData path, shown as a picture of the block, with
##   block_values  its slots filled ("list:route" puts route's name block in).
##   targets       What stays lit and clickable. Paths from the Puzzle root;
##                 "block:Name" for a toolbox block by data name; "level:Path"
##                 for a node in the level, such as a list's board.
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
		{title = "Welcome!", text = "You will tell a robot what to do, with blocks. Let's look around first.",
			button = "Start"},
		{title = "The room", text = "This is the robot's room. Get the robot to the red flag.",
			targets = [ROOM]},
		{title = "Look around", text = "Drag the room to move it. Scroll to zoom. Then press this button to put it back.",
			targets = [ROOM, RIGHT_BUTTONS + "FrameButton"], advance = Advance.VIEW_FRAMED},
		{title = "Need more space?", text = "This button hides the room. Press it.",
			targets = [RIGHT_BUTTONS + "EnvironmentButton"], advance = Advance.PANEL_CLOSED},
		{title = "Bring it back", text = "Press it again to show the room.",
			targets = [RIGHT_BUTTONS + "EnvironmentButton"], advance = Advance.PANEL_OPENED},
		{title = "Your task", text = "Every level's task is here. Read it before you start.",
			focus = LEFT + "/PuzzleInformation", targets = [LEFT, LEFT_BUTTONS + "InfoMenuButton"]},
		{title = "Your blocks", text = "The blocks you can use are here.",
			focus = TOOLBOX, targets = [LEFT, LEFT_BUTTONS + "ToolboxMenuButton"]},
		{title = "Place a block", text = "Drag move forward into the begin block.",
			graphic = GRAPHICS + "drag_into_begin.tscn",
			focus = TOOLBOX, targets = [LEFT, WORKSPACE], advance = Advance.BLOCK_PLACED, only = "MoveBlock"},
		{title = "Throw it away", text = "Drag the block onto the trash can.",
			targets = [LEFT_BUTTONS + "TrashButton", WORKSPACE], advance = Advance.BLOCK_TRASHED},
		{title = "Put it back", text = "Drag move forward into begin again.",
			focus = TOOLBOX, targets = [LEFT, WORKSPACE], advance = Advance.BLOCK_PLACED, only = "MoveBlock"},
		{title = "The menu", text = "This opens the menu. You can also press the Esc key. Open it now.",
			targets = [RIGHT_BUTTONS + "MenuButton"], advance = Advance.MENU_OPENED},
		{title = "The menu", text = "Go back to the levels, or see a level's tutorial again. Press Resume to close it.",
			dim = false, card = "top", advance = Advance.MENU_CLOSED},
		{title = "Run it", text = "Press Play to run your blocks. The X stops them.",
			targets = [RIGHT_BUTTONS + "PlayButton", RIGHT_BUTTONS + "StopButton"], advance = Advance.RUN_STARTED},
		{title = "Watch", text = "Watch the robot follow your blocks.",
			dim = false, block_input = true, card = "top", advance = Advance.RUN_FINISHED},
	],
	&"assistant": [
		{title = "Stuck? Ask for help", text = "Tell the assistant what you expected and what happened. It asks questions back. It won't give the answer.",
			focus = LEFT + "/AIAssistant", targets = [LEFT, LEFT_BUTTONS + "AIAssistantMenuButton"], button = "Got it"},
	],
	&"variables": [
		{title = "Your variables", text = "While the program runs, this tab shows every variable and its value.",
			focus = LEFT + "/VariableWatcher", targets = [LEFT, LEFT_BUTTONS + "VariableWatcherMenuButton"]},
		{title = "Answers on blocks", text = "Blocks that work something out show their answer in a small tag while the program runs.",
			graphic = GRAPHICS + "answer_tag.tscn", button = "Got it"},
	],
	&"lists": [
		{title = "This is a list", text = "One name, many values, in order.",
			graphic = GRAPHICS + "list_parts.tscn", targets = ["level:Visuals/Lists/Room1/route"]},
		{title = "Index", text = "The small number under each value is its index: its place in line. The first one is 0.",
			graphic = GRAPHICS + "list_index.tscn", targets = ["level:Visuals/Lists/Room1/route"]},
		{title = "item ... of ...", text = "Gives you the value at an index.",
			graphic = GRAPHICS + "item_of.tscn", focus = TOOLBOX, targets = ["block:ItemOfBlock"]},
		{title = "Watch", text = "The robot reads the list, then walks that far.",
			button = "Watch it run"},
	],
	&"list_names": [
		{title = "A list's name block", text = "Each list has a name block. Drop it into a block's list slot.",
			graphic = GRAPHICS + "name_block.tscn", focus = TOOLBOX, targets = ["block:List_route", "block:ItemOfBlock"], button = "Got it"},
	],
	&"goal_marks": [
		{title = "What it should be", text = "A small green number is what that box should hold at the end.",
			graphic = GRAPHICS + "goal_corner.tscn", targets = ["level:Visuals/Lists/Room1/lockers"]},
		{title = "Right or wrong?", text = "When your program changes a value, green means right. Red means wrong.",
			graphic = GRAPHICS + "goal_checked.tscn", targets = ["level:Visuals/Lists/Room1/lockers"], button = "Got it"},
	],
	&"empty_list": [
		{title = "An empty list", text = "This list starts empty. The faded values show what it should hold at the end.",
			graphic = GRAPHICS + "goal_faded.tscn", targets = ["level:Visuals/Lists/Room1/passed"], button = "Got it"},
	],
}

## Which sets a level gets, in order, keyed by scene file name. "blocks" stands
## for a page per new block, made from the level's own description. A level not
## listed gets just those, if it has any new blocks.
const LEVELS := {
	"tutorial_1": [&"first_steps"],
	"it_1": [&"blocks", &"assistant"],
	"it_4": [&"blocks", &"variables"],
	"ar_1": [&"lists"],
	"ar_2": [&"list_names", &"blocks"],
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
			pages.append_array(block_pages(level))
		elif SETS.has(item):
			pages.append_array(SETS[item])
		else:
			push_warning("Guides: level '%s' names a set '%s' that doesn't exist." % [key, item])
	return pages

## A page per block the level introduces, from its description: the block's
## picture, its note, and the block lit in the toolbox.
static func block_pages(level: Level) -> Array:
	var description := level.description
	if description == null:
		return []
	var pages: Array = []
	for i in description.blocks.size():
		var data := description.blocks[i]
		if data == null:
			continue
		var values: PackedStringArray = []
		if i < description.block_values.size():
			values = description.block_values[i].split(",", true)
		pages.append({
			title = "New block",
			block = data,
			block_values = values,
			text = description.block_notes[i] if i < description.block_notes.size() else "",
			focus = TOOLBOX,
			targets = ["block:" + data.name],
		})
	return pages
