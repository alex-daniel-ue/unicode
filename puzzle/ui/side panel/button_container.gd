extends VBoxContainer

# Called by child buttons, used to funnel their signals into one
@warning_ignore("unused_signal")
signal button_pressed

var is_side_panel_button := func(node: Node) -> bool: return node is SidePanelButton

@export var panel: SidePanel


func _ready() -> void:
	for child in get_children().filter(is_side_panel_button):
		(child as SidePanelButton).contents_visibility_requested.connect(panel.show_content)
