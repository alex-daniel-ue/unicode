class_name Set
extends Resource

const VALUE = 0

var map: Dictionary

func _init():
	map = Dictionary()

# Adds an element to the set
func add(element):
	map[element] = VALUE

# Adds multiple elements to the set
func add_all(elements: Array):
	for element in elements:
		add(element)

# Removes an element from the set
func remove(element):
	map.erase(element)

# Removes multiple elements from the set
func remove_all(elements: Array):
	for element in elements:
		remove(element)

# Removes elements that match a condition (predicate function)
func remove_matching(matcher: Callable):
	for element in map.keys():
		if matcher.call(element):
			remove(element)

# Checks if an element exists in the set
func contains(element) -> bool:
	return map.has(element)

# Returns the set as an array of elements
func get_as_array() -> Array:
	return map.keys()

# Clears all elements from the set
func clear():
	map.clear()

# Checks if the set is empty
func is_empty() -> bool:
	return map.is_empty()

# Returns the number of elements in the set
func size() -> int:
	return map.size()

# Returns a new Set that is the intersection of this set and another set
func intersection(other_set: Set) -> Set:
	var result = Set.new()
	for element in map.keys():
		if other_set.contains(element):
			result.add(element)
	return result

# Returns a new Set that is the union of this set and another set
func union(other_set: Set) -> Set:
	var result = Set.new()
	for element in map.keys():
		result.add(element)
	for element in other_set.get_as_array():
		result.add(element)
	return result

# Returns a new Set that is the difference of this set and another set (elements in this set but not in the other)
func difference(other_set: Set) -> Set:
	var result = Set.new()
	for element in map.keys():
		if not other_set.contains(element):
			result.add(element)
	return result

# Returns a new Set that contains the symmetric difference (elements in either set, but not both)
func symmetric_difference(other_set: Set) -> Set:
	var result = Set.new()
	for element in map.keys():
		if not other_set.contains(element):
			result.add(element)
	for element in other_set.get_as_array():
		if not contains(element):
			result.add(element)
	return result
