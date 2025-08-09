class_name NestedBlockData
extends BlockData


enum Type {
	NULL,
	IF,
	ELSE,
	ELIF,
	WHILE,
	FOR,
	REPEAT,
	BEGIN,
	FUNCTION,
}

@export_group("Nested")
@export var nested_type: Type
