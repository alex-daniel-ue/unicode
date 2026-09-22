class_name LevelEntry
extends Resource

## One level. `id` is the progress key and the analysis key, it must match the
## id used in the thesis data, so pick it once and never rename it.

@export var id: StringName = &""

## Grid button face. Keep it to one or two characters ("1", "0a").
@export var label := "1"

## Full name for the header and for the tooltip: "Until the wall".
@export var title := ""

## One line naming the concept, shown under the title on hover.
@export var concept := ""

@export var scene: PackedScene

## False for the tutorial and any other level that should not consume a
## ProgressCode slot or appear in the study's completion data.
@export var counts_for_progress := true

## Holds a progress slot for a level that has been pulled after codes were
## issued. Keeps every code already in students' hands readable.
@export var retired := false
