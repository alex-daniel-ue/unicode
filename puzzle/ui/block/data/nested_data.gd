class_name NestedData
extends Resource
## A nested block's kind, for the interpreter: what its mouth is for.

## Stored as an integer in every .tres, so only ever append: a new type in the
## middle renumbers everything after it, Begin included.
enum Type {
	NULL,
	IF, ELSE, ELIF,
	WHILE, FOR, REPEAT,
	BEGIN, FUNCTION,
	FOR_EACH,
}

@export var type: Type
