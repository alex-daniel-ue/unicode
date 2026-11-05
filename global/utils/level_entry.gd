@tool
class_name LevelEntry
extends Resource
## One level in the LevelCatalog.

## The progress key, and the key of the level in the study's data, so it never
## changes once a level has shipped.
@export var id: StringName = &""
## Grid button face. Keep it to one or two characters ("1", "0a").
@export var label := "1"
## Full name for the header and for the tooltip: "Until the wall".
@export var title := ""
## One line naming the concept, shown under the title on hover.
@export var concept := ""
@export var scene: PackedScene
## False for the tutorial and any other level that should not take a
## ProgressCode slot or appear in the study's completion data.
@export var counts_for_progress := true
## Holds the progress slot of a level pulled after codes were handed out, so
## every code already in students' hands still reads.
@export var retired := false
