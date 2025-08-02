class_name NestedBlockData
extends BlockData


enum NestedType {
	IF,
	ELSE,
	WHILE,
	FOR,
	REPEAT,
	BEGIN
}

@export_group("Nested")
@export var nested_type: NestedType
