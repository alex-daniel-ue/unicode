extends Control


@onready var side_menus := [
	$LeftSideMenu,
	$RightSideMenu
]

func _on_canvas_clicked() -> void:
	for side_menu in side_menus:
		side_menu.show_menu(false)
