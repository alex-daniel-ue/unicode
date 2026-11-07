class_name FileFunctions
extends Node
## What the file blocks do: a file's name block, and Write. Reading is For Each
## (a file gives its lines), Length Of (how many lines) and In (a word in a
## line), as in Python.


## <the file's name>
func _file_reporter(this: Block) -> Variant:
	var file_name := this.data.func_entity_name
	var file := FileEntity.find(file_name)
	if file == null:
		this.function.error("There's no file named %s here." % file_name)
		return null
	return file


## write {text} to {file}
##
## Python's f.write() takes text only: a number has to be made text first, with
## str() or an f-string, which is what a student writing numbers learns.
func _write_line(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var text: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var file := this.function.resolve(args[1], FileEntity, "a file") as FileEntity
	if file == null: return
	if typeof(text) != TYPE_STRING:
		this.function.error("Write needs text, but it got %s. Make it text with str( ), or with an f-string." % Core.to_python_repr(text))
		return
	await file.write_line(text, this)
