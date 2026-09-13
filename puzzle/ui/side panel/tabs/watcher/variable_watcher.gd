class_name VariableWatcher
extends Control


const COL_NAME := 0
const COL_VALUE := 1
const COL_TYPE := 2

## Friendly type names, matching the wording Core.validate_type() uses in block
## errors. Keep the two in sync — a student who reads "must be an integer" in a
## red block shouldn't then see "int" here.
const TYPE_NAMES := {
	TYPE_BOOL: "Boolean",
	TYPE_INT: "integer",
	TYPE_FLOAT: "decimal",
	TYPE_STRING: "string",
	TYPE_STRING_NAME: "variable name",
}

@export var tree: Tree
@export var status: Label
@export var status_container: Container

@export var frame_color := Color(0.62, 0.68, 0.80)
@export var stale_color := Color(0.55, 0.55, 0.55)

var _dirty := true


func _ready() -> void:
	tree.set_column_title(COL_NAME, "Name")
	tree.set_column_title(COL_VALUE, "Value")
	tree.set_column_title(COL_TYPE, "Type")
	tree.set_column_expand_ratio(COL_NAME, 4)
	tree.set_column_expand_ratio(COL_VALUE, 4)
	tree.set_column_expand_ratio(COL_TYPE, 3)
	
	Interpreter.scope_changed.connect(_on_scope_changed)
	Interpreter.running_changed.connect(_on_interpreter_running_changed)
	
	_rebuild()


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	_rebuild()


func _on_scope_changed() -> void:
	# Coalesce. In fast mode scope_changed fires several times per block, and a
	# rebuild per emit is wasted work — one per frame is plenty.
	_dirty = true


func _on_interpreter_running_changed() -> void:
	if Interpreter.is_running:
		focus_self()
	_dirty = true


## Brings this tab forward without toggling the panel shut.
func focus_self() -> void:
	var panel := get_parent() as SidePanel
	if panel != null:
		panel.focus_content(self)


func _rebuild() -> void:
	tree.clear()
	
	var is_stale := not Interpreter.is_running
	var errored := not Interpreter.frozen_scopes.is_empty()
	
	# Untyped on purpose: Array[Interpreter.Frame] is an inner class and the
	# analyzer doesn't reliably accept it as a typed-array element.
	var frames: Array = Interpreter.frozen_scopes if (is_stale and errored) \
		else Interpreter.scopes
	
	if frames.is_empty():
		_show_message("Variable watcher inactive. Press play to activate.")
		return
	
	var total := 0
	for frame in frames:
		total += frame.vars.size()
	
	if total == 0 and not is_stale:
		_show_message("No variables yet.")
		return
	
	tree.show()
	if is_stale:
		status.show()
		if not Interpreter.active_errors.is_empty():
			status.text = "Variables when the error happened."
		elif errored:
			status.text = "Variables when the program stopped."
		else:
			status.text = "Variables at the end of your last run."
	else:
		status_container.hide()
	
	var text_color := stale_color if is_stale else frame_color
	
	var root := tree.create_item()
	var parent_item := root
	var frame_item: TreeItem = null
	var previous_owner := 0
	
	for frame in frames:
		# A for-loop opens two frames: one holding the counter, and one per pass
		# of the body. Both belong to the same block, so show a single heading.
		if frame_item == null or frame.owner_id != previous_owner:
			frame_item = tree.create_item(parent_item)
			frame_item.set_text(COL_NAME, frame.label.replace("\n", " "))
			for col in 3:
				frame_item.set_selectable(col, false)
				frame_item.set_custom_color(col, text_color)
			parent_item = frame_item
			previous_owner = frame.owner_id
			
			# Each frame nests inside the one before it, so the indentation in
			# the tree is the scope nesting on the canvas.
			parent_item = frame_item
		
		for var_name in frame.vars:
			var value: Variant = frame.vars[var_name]
			var item := tree.create_item(frame_item)
			item.set_text(COL_NAME, str(var_name))
			item.set_text(COL_VALUE, _display_value(value))
			item.set_text(COL_TYPE, _display_type(value))
			if is_stale:
				for col in 3:
					item.set_custom_color(col, stale_color)


func _show_message(message: String) -> void:
	tree.hide()
	status_container.show()
	status.text = message


func _display_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "not set yet"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_STRING, TYPE_STRING_NAME:
			# Quoted so "5" and 5 don't look identical — that difference is
			# exactly what comparison's type errors are about.
			return "\"%s\"" % value
		_:
			return str(value)


func _display_type(value: Variant) -> String:
	if value == null:
		return "—"
	return TYPE_NAMES.get(typeof(value), type_string(typeof(value)))
