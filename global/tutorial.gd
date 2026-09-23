extends Node

## Events the tutorial overlay listens for. They are emitted where the thing
## already happens (drop_manager, trash_button, ai_assistant), so the overlay
## needs no node paths into the puzzle's UI and works for any level.
@warning_ignore("unused_signal")
signal block_placed(block: Block, into: Block)
@warning_ignore("unused_signal")
signal block_trashed(block_name: StringName)
@warning_ignore("unused_signal")
signal message_sent(text: String)
@warning_ignore("unused_signal")
signal assistant_replied(text: String)


var shift_enter_shown := false
