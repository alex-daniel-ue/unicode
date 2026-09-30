@tool
extends EditorScript

## Level lint. Open it in the script editor and press Run (Ctrl+Shift+X).
##
## The checks live in level_lint_core.gd (LevelLint), so the same lint also runs
## headless from a terminal:
##   godot --headless --path . res://tools/level_lint.tscn


func _run() -> void:
	LevelLint.new().run()
