class_name NestedData
extends Resource


enum Type {
	NULL,
	IF, ELSE, ELIF,
	WHILE, FOR, REPEAT,
	BEGIN, FUNCTION
}

@export var type: Type
