@tool
extends Control


@onready var margin_container := $MarginContainer:
	get():
		if not margin_container:
			margin_container = find_child("MarginContainer", false, false)
		return margin_container


func _on_margin_container_resized() -> void:
	custom_minimum_size = margin_container.size
