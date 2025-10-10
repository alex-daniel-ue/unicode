extends Node


signal protag_text_changed

@export var father_label: Label
@export var protag_label: Label

var father_text: String:
	set(value):
		father_text = value
		father_label.text = father_text

var protag_text: String:
	set(value):
		protag_text = value
		protag_label.text = protag_text
		protag_text_changed.emit()


## text: say {string/variable}
func say(from_this: Block) -> void:
	var args: Array = await from_this.function.evaluate_args(1)
	if Puzzle.has_errored:
		return
	
	var value: Variant = args[0]
	if typeof(value) == TYPE_STRING_NAME:
		var parent_nested := from_this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
		
		if not parent_nested.scope.has(value):
			from_this.function.error("Variable '%s' doesn't exist in the current scope!" % value)
			return
		
		value = parent_nested.scope[value]
	
	var err_message := Core.validate_type(value, [TYPE_STRING], 0)
	if not err_message.is_empty():
		from_this.function.error(err_message)
		return
	
	protag_text = value
	
	from_this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	from_this.visual.reset()

func get_father_text(from_this: Block) -> String:
	from_this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	from_this.visual.reset()
	
	return father_text
