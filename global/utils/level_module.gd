@tool
class_name LevelModule
extends Resource

## One teaching module, Iteration, Arrays. Ten levels each, per the panel's
## instruction.

@export var id: StringName = &""
@export var display_name := "Module"

## Shown under the module name on the level select screen.
@export var subtitle := ""

@export var levels: Array[LevelEntry] = []

## Deployment gate. The study releases each module on the day the professor
## teaches that topic, so a build can ship with both modules present and only
## one reachable. `unicode.cfg` overrides this at runtime (see LevelSelect), so
## lab day is a text edit rather than a rebuild.
@export var released := true

## Shown in place of the level grid when the module is not released.
@export var locked_notice := "Opens when your instructor covers this topic."
