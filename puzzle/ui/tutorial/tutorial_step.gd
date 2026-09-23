class_name TutorialStep
extends Control

## One screen of the tutorial. Put text, images, looping clips (a
## VideoStreamPlayer with an .ogv: Godot has no GIF loader) and inert Blocks
## inside it, laid out however you like. The overlay shows one step at a time,
## in child order, and moves on when `advance_on` happens.

enum Advance {
	NEXT_BUTTON,        ## next_button was pressed
	BLOCK_PLACED,       ## a block was dropped into a mouth (Begin, while, ...)
	BLOCK_TRASHED,      ## a block was dragged onto the bin
	RUN_STARTED,        ## Play started a run
	RUN_FINISHED,       ## the run ended, whatever the outcome
	ROOM_COMPLETED,     ## one room of a multi-room level was solved
	LEVEL_COMPLETED,    ## the level was solved
	ERROR_RAISED,       ## a block raised an error
	MESSAGE_SENT,       ## the student sent the assistant a message
	ASSISTANT_REPLIED,  ## the assistant answered
}

## What moves the tutorial past this screen.
@export var advance_on := Advance.NEXT_BUTTON

## For BLOCK_PLACED and BLOCK_TRASHED: only this block counts, by its data name
## ("MoveBlock"). Empty means any block.
@export var only_block := ""

## What this screen points at: paths from the Puzzle root, which stay lit and
## clickable through the dim. "block:MoveBlock" lights the first toolbox block
## with that data name.
@export var targets: PackedStringArray = []

## A side panel tab to open when this screen appears, as a path from the Puzzle
## root to the tab's content ("UserInterface/SideMenuLeft/Panel/PuzzleToolbox").
## The overlay calls SidePanel.focus_content() on it, so the thing the card talks
## about is already on screen instead of the student hunting for its button.
@export var focus_panel := ""

## Dim everything except the targets.
@export var dim := true

## Swallow every click, targets included: for "watch the program run" screens.
## The keyboard and the pause menu still get through.
@export var block_input := false

## Pressed to advance when advance_on is NEXT_BUTTON.
@export var next_button: BaseButton
