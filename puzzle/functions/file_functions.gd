class_name FileFunctions
extends Node

## The file blocks: a file's name block, and Write. Reading is For Each (a
## file gives its lines), Length Of (how many lines) and In (a word in a line),
## as in Python.


## text: <the file's name>
func _file_reporter(this: Block) -> Variant:
	var file_name := this.data.func_entity_name
	var file := FileEntity.find(file_name)
	if file == null:
		this.function.error("There's no file named %s here." % file_name)
		return null
	return file

## text: write {text} to {file}
##
## Python's f.write() takes text only: a number has to be made text first, with
## str() or an f-string, which is what a student writing numbers learns.
func _write_line(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var text: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var file := resolve(this, args[1])
	if file == null: return
	if typeof(text) != TYPE_STRING:
		this.function.error("Write needs text, but it got %s. Make it text with str( ), or with an f-string." % Core.to_python_repr(text))
		return
	await file.write_line(text, this)

static func resolve(this: Block, raw: Variant) -> FileEntity:
	var value: Variant = this.function.unwrap(raw)
	if Interpreter.interrupted:
		return null
	if value is FileEntity:
		return value
	var block_name := this.data.display_name() if this.data != null else "this"
	if value == null:
		this.function.error("The %s block needs a file. Drop the name block of a file into its empty slot." % block_name)
	else:
		this.function.error("The %s block needs a file, but it got %s." % [block_name, Core.to_python_repr(value)])
	return null
