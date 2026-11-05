@tool
class_name LevelModule
extends Resource
## One teaching module of the LevelCatalog: Iteration, Arrays, and so on.

@export var id: StringName = &""
@export var display_name := "Module"
## Shown under the module name on the level select screen.
@export var subtitle := ""
@export var levels: Array[LevelEntry] = []
## Release gate: a module opens on the day its topic is taught, so a build can
## ship with every module in it and only some reachable. unicode.cfg overrides
## this at runtime (see LevelSelect), so opening one is a text edit, not a rebuild.
@export var released := true
## Shown in place of the level grid when the module is not released.
@export var locked_notice := "Opens when your instructor covers this topic."
