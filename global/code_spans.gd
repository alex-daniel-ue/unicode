class_name CodeSpans
extends RefCounted

## Turns text with bits of Python in it into BBCode where the Python stands out:
## a different font on a tinted chip, so `for leg in route:` reads as code and
## not as a sentence that suddenly stopped making sense.
##
## The model is asked to put code in backticks. When it doesn't, mark() finds
## the usual shapes of Python in the sentence (a loop or if header, a call, an
## index, an assignment) and backticks them itself, so prose never runs straight
## into code either way. A loop or if header only counts with its colon (or a
## call in it): "for loops in games" is English.

const CODE_COLOR := "#ffd166"
const CHIP_COLOR := "#ffffff1a"

## Python that turns up in English sentences, most specific first.
const PATTERNS := [
	# for leg in route:   for i in range(1, 5):
	"\\bfor\\s+[A-Za-z_]\\w*\\s+in\\s+[A-Za-z_][\\w.]*(?:\\([^()]*\\))?:",
	# while not ahead_is("blocked")   while i < 3:
	"\\bwhile\\s+(?:not\\s+)?(?:[A-Za-z_][\\w.]*\\([^()]*\\):?|[A-Za-z_]\\w*\\s*(?:==|!=|>=|<=|<|>)\\s*[\\w.\"']+:)",
	# if s >= 75:   if s in choir:
	"\\bif\\s+(?:not\\s+)?[A-Za-z_]\\w*\\s*(?:==|!=|>=|<=|<|>|\\bnot\\s+in\\b|\\bin\\b)\\s*[\\w.\"']+:",
	# passed.append(s)   len(route)   range(0, row)
	"\\b[A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*\\([^()\\n]*\\)",
	# route[0]   lockers[i] = i + 1
	"\\b[A-Za-z_]\\w*\\[[^\\]\\n]*\\](?:\\s*=\\s*[\\w.+\\- ]+)?",
	# i += 1
	"\\b[A-Za-z_]\\w*\\s*(?:\\+=|-=|\\*=)\\s*[\\w.]+",
]


## `text` with every bit of Python in backticks: the model's own, and any it left bare.
static func mark(text: String) -> String:
	var out := ""
	var parts := text.split("`")
	for i in parts.size():
		if i % 2 == 1:
			out += "`" + parts[i] + "`"  # already code
		else:
			out += _mark_prose(parts[i])
	return out

## BBCode for `text`: backticked spans as code chips, everything else escaped so
## a bracket in it can't start a tag.
static func to_bbcode(text: String) -> String:
	var out := ""
	var parts := mark(text).split("`")
	for i in parts.size():
		var piece := parts[i].replace("[", "[lb]")
		if i % 2 == 1 and not piece.strip_edges().is_empty():
			out += "[bgcolor=%s][color=%s][code] %s [/code][/color][/bgcolor]" % [CHIP_COLOR, CODE_COLOR, piece]
		else:
			out += piece
	return out

static func _mark_prose(prose: String) -> String:
	var spans: Array[Vector2i] = []
	for pattern: String in PATTERNS:
		var regex := RegEx.create_from_string(pattern)
		for found in regex.search_all(prose):
			var span := Vector2i(found.get_start(), found.get_end())
			# Trailing sentence punctuation belongs to the sentence, not the code.
			while span.y > span.x and prose[span.y - 1] in [".", ","]:
				span.y -= 1
			if not spans.any(func(other: Vector2i) -> bool: return span.x < other.y and other.x < span.y):
				spans.append(span)
	spans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var out := ""
	var at := 0
	for span in spans:
		out += prose.substr(at, span.x - at) + "`" + prose.substr(span.x, span.y - span.x) + "`"
		at = span.y
	return out + prose.substr(at)
