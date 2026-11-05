extends VBoxContainer
## The column of buttons beside a side panel: each SidePanelButton in it shows
## its tab on `panel`.

@export var panel: SidePanel


func _ready() -> void:
	for child in get_children():
		if child is SidePanelButton:
			(child as SidePanelButton).contents_visibility_requested.connect(panel.show_content)
