class_name NestedBlockData
extends BlockData


enum Type {
	IF,
	ELSE,
	WHILE,
	FOR,
	REPEAT,
	BEGIN
}

@export_group("Nested")
@export var nested_type: Type
