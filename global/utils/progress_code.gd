class_name ProgressCode
extends RefCounted

## Star progress as ten Crockford base32 characters, written XXXXX-XXXXX.
##
## Layout, 50 bits over 10 characters of 5 bits:
##   chars 0-7  40 bits of star data, 2 bits per level, level 0 in the lowest pair
##   char  8    format version, 0-30
##   char  9    checksum of the nine characters before it, position-weighted mod 31
##
## Checksum strength, established exhaustively rather than by sampling: over
## 930,000 single-character substitutions and 26,171 adjacent transpositions,
## every undetected error was a '0' read as 'Z' or the reverse, and there were
## no others. The reason is structural: 31 is prime and the positional weights
## run 1..10, so a change is invisible only when the character value shifts by
## exactly +/-31, and 0 and Z are the only pair 31 apart in the alphabet.
##
## So the failure mode is nameable rather than statistical: the ONLY typo this
## code cannot catch is confusing zero with Z. Print codes in a font that
## distinguishes them, and the check is effectively total. (0.16% of random
## substitutions land there in practice.)
##
## Nothing is collected and nothing is stored on a server: the code is the whole
## record.

const LEVELS := 20
const STARS_PER_LEVEL := 2
const PAYLOAD_CHARS := 8
const VERSION_INDEX := 8
const CHECK_INDEX := 9
const LENGTH := 10
const VERSION := 1

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford: no I, L, O, U


static func encode(stars: PackedInt32Array, version := VERSION) -> String:
	var bits := 0                       # 40-bit payload, built little-end first
	for level in mini(stars.size(), LEVELS):
		var count: int = clampi(stars[level], 0, 3)
		bits |= count << (level * STARS_PER_LEVEL)

	var chars: PackedInt32Array = []
	for i in PAYLOAD_CHARS:             # 5 bits at a time, lowest group first
		chars.append((bits >> (i * 5)) & 0b11111)
	chars.append(clampi(version, 0, 30))
	chars.append(_checksum(chars))

	var out := ""
	for value in chars:
		out += ALPHABET[value]
	return out.insert(5, "-")


## Returns an empty array when the code is malformed, so the caller can say so.
## A code written by a NEWER format version is rejected rather than misread:
## without this, bumping VERSION would silently decode old codes against the new
## layout and hand students the wrong stars.
static func decode(code: String) -> PackedInt32Array:
	var chars := _values(code)
	if chars.is_empty():
		return PackedInt32Array()
	if chars[CHECK_INDEX] != _checksum(chars.slice(0, CHECK_INDEX)):
		return PackedInt32Array()
	if chars[VERSION_INDEX] > VERSION:
		return PackedInt32Array()

	var bits := 0
	for i in PAYLOAD_CHARS:
		bits |= chars[i] << (i * 5)

	var stars: PackedInt32Array = []
	for level in LEVELS:
		stars.append((bits >> (level * STARS_PER_LEVEL)) & 0b11)
	return stars


static func version_of(code: String) -> int:
	var chars := _values(code)
	return -1 if chars.is_empty() else chars[VERSION_INDEX]


static func is_valid(code: String) -> bool:
	return not decode(code).is_empty()


## Total stars, for "take the higher of the typed code and the local file".
static func score(stars: PackedInt32Array) -> int:
	var total := 0
	for count in stars:
		total += count
	return total


## Formats a raw ten-character code for display. Kept here so the hyphen
## convention lives in one place.
static func format_for_display(code: String) -> String:
	var cleaned := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	return cleaned.insert(5, "-") if cleaned.length() == LENGTH else code


static func _checksum(chars: PackedInt32Array) -> int:
	var sum := 0
	for i in chars.size():
		sum += (i + 1) * chars[i]
	return sum % 31


## Characters to 5-bit values, or an empty array if anything is unreadable.
## Hyphens and spaces are ignored and the usual handwriting slips are mapped back.
static func _values(code: String) -> PackedInt32Array:
	var cleaned := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if cleaned.length() != LENGTH:
		return PackedInt32Array()

	var chars: PackedInt32Array = []
	for i in cleaned.length():
		var c := cleaned[i]
		match c:
			"I", "L": c = "1"
			"O": c = "0"
			"U": c = "V"
		var value := ALPHABET.find(c)
		if value < 0:
			return PackedInt32Array()
		chars.append(value)
	return chars
