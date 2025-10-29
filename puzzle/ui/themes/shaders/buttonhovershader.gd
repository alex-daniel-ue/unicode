extends Button

func _ready():
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_mouse_entered():
	material.set_shader_param("hover", true)

func _on_mouse_exited():
	material.set_shader_param("hover", false)
