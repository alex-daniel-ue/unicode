class_name Puzzle
extends Control


const MAX_LOOPS := 1000
const MAX_DEPTH := 100


@onready var canvas := $Canvas as ColorRect
@onready var side_menus := [
	$LeftSideMenu,
	$RightSideMenu
]

func run_program() -> void:
	var begin := _get_begin()
	if begin == null:
		push_warning("No start block detected!")
		return
	
	var result := await begin.function.call() as Utils.Result
	if result is Utils.Error:
		printt(result.message, result.block)
		# show message
		# highlight block with error
		pass

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.data.nested_type == NestedBlockData.Type.BEGIN:
				return child
	return null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		run_program()

func _on_canvas_clicked() -> void:
	for side_menu in side_menus:
		side_menu.show_menu(false)
