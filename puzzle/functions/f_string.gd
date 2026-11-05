class_name FString
extends RefCounted

## Text typed into a slot the way Python writes it: "quotes", the escape codes
## \n, \t, \\, \" and \', and f-strings, f"Hello, {name}!", whose {name} is
## the value of that variable when the block runs. That is Python's string
## formatting with nothing new to learn: the slot already took "text" in
## quotes, and an f in front makes it a template.
##
## In braces: a variable's name, or a list's, and optionally a format after a
## colon: {price:.2f} for two decimal places, {n:d} for a whole number. {{ and }}
## are a brace itself, as in Python.


static func is_f_string(raw: String) -> bool:
	if raw.length() < 3:
		return false
	var quote := raw[1]
	return raw[0] in ["f", "F"] and quote in ['"', "'"] and raw[raw.length() - 1] == quote

## The text inside an f-string's quotes, before its braces are filled. What a
## slot shows as its type and colour: an f-string is text.
static func template_of(raw: String) -> String:
	return unescape(raw.substr(2, raw.length() - 3))

## Python's escape codes in the text between quotes.
static func unescape(text: String) -> String:
	if not "\\" in text:
		return text
	var out := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "\\" and i + 1 < text.length():
			var next := text[i + 1]
			match next:
				"n": out += "\n"
				"t": out += "\t"
				"\\": out += "\\"
				"\"": out += "\""
				"'": out += "'"
				_: out += c + next
			i += 2
			continue
		out += c
		i += 1
	return out

## The f-string `raw` with its braces filled, or null after raising the error
## on `block`.
static func format(block: Block, raw: String) -> Variant:
	var template := template_of(raw)
	var out := ""
	var i := 0
	while i < template.length():
		var c := template[i]
		if c == "{" and i + 1 < template.length() and template[i + 1] == "{":
			out += "{"
			i += 2
			continue
		if c == "}" and i + 1 < template.length() and template[i + 1] == "}":
			out += "}"
			i += 2
			continue
		if c == "}":
			block.function.error("This f-string has a } with no { before it. To show a brace, write }}.")
			return null
		if c != "{":
			out += c
			i += 1
			continue
		var close := template.find("}", i)
		if close < 0:
			block.function.error("This f-string has a { with no } after it.")
			return null
		var inside := template.substr(i + 1, close - i - 1).strip_edges()
		var filled: Variant = _fill(block, inside)
		if filled == null:
			return null
		out += filled
		i = close + 1
	return out

static func _fill(block: Block, inside: String) -> Variant:
	var spec := ""
	var colon := inside.find(":")
	var name := inside
	if colon >= 0:
		name = inside.substr(0, colon).strip_edges()
		spec = inside.substr(colon + 1).strip_edges()
	if name.is_empty():
		block.function.error("This f-string has empty braces {}. Put a variable's name in them.")
		return null
	if not name.is_valid_ascii_identifier():
		block.function.error("In an f-string, only a variable's name can go between { and }, but this has '%s'. Work it out into a variable first." % name)
		return null
	var value: Variant = block.function.unwrap(StringName(name))
	if Interpreter.interrupted:
		return null
	if spec.is_empty():
		return Core.to_python_literal(value)
	if spec == "d":
		if typeof(value) != TYPE_INT:
			block.function.error("{%s:d} needs a whole number, but %s is %s." % [name, name, Core.to_python_repr(value)])
			return null
		return str(value)
	if spec.begins_with(".") and spec.ends_with("f") and spec.substr(1, spec.length() - 2).is_valid_int():
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			block.function.error("{%s:%s} needs a number, but %s is %s." % [name, spec, name, Core.to_python_repr(value)])
			return null
		var places := spec.substr(1, spec.length() - 2).to_int()
		return ("%." + str(places) + "f") % float(value)
	block.function.error("'{%s:%s}' isn't a format this game knows. It knows {x}, {x:d} and {x:.2f}." % [name, spec])
	return null
