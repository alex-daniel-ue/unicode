class_name SidePanelButton
extends Button
## A button beside a side panel that shows one of its tabs, or shuts the panel
## when that tab is already showing (SidePanel.show_content()).

signal contents_visibility_requested(contents: Control)

@export var associated_contents: Control
## Optional: the icon while the panel is open, and while it is shut. The room's
## button points the way the panel will move when pressed.
@export var open_icon: Texture2D
@export var closed_icon: Texture2D


func _ready() -> void:
	pressed.connect(contents_visibility_requested.emit.bind(associated_contents))
	var panel := associated_contents.get_parent() as SidePanel if associated_contents != null else null
	if panel != null and (open_icon != null or closed_icon != null):
		panel.toggled.connect(_on_panel_toggled)
		_on_panel_toggled(panel.is_open)


func _on_panel_toggled(open: bool) -> void:
	var wanted := open_icon if open else closed_icon
	if wanted != null:
		icon = wanted
