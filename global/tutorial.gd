extends Node

## Events the tutorial overlay listens for. They are emitted where the thing
## already happens (drop_manager, trash_button, canvas, ai_assistant, the side
## panels, the pause menu), so the overlay needs no node paths into the puzzle's
## UI and works for any level.
@warning_ignore("unused_signal")
signal block_placed(block: Block, into: Block)
@warning_ignore("unused_signal")
signal block_trashed(block_name: StringName)
@warning_ignore("unused_signal")
signal message_sent(text: String)
@warning_ignore("unused_signal")
signal assistant_replied(text: String)
## The pause menu opened or closed.
@warning_ignore("unused_signal")
signal menu_toggled(open: bool)
## A side panel was opened or closed by its button.
@warning_ignore("unused_signal")
signal panel_toggled(panel: SidePanel, open: bool)
## The reframe button put the level view back.
@warning_ignore("unused_signal")
signal view_framed


var shift_enter_shown := false
