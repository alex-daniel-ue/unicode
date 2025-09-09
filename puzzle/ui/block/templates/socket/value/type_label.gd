extends Label


const type_names: Dictionary[Variant.Type, String] = {
	TYPE_NIL: "",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "string",
	TYPE_STRING_NAME: "var",
}

@export var base: ValueBlock


func update_type(_unused_arg: Variant = null) -> void:
	var type := typeof(base.typecast(base.text.get_raw()))
	visible = type != TYPE_NIL
	text = type_names[type]
