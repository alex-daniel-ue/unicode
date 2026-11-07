class_name StatementBlock
extends Block
## A block that does one thing and stacks between others: Step Forward, Turn,
## Set, Append. Block holds everything it needs. This class exists because Block
## is abstract, and so drag and drop and the interpreter can tell a statement
## from a nested block or a slot (`is StatementBlock`).
