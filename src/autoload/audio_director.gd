extends Node
## Stage 6 placeholder: 4-stem AudioStreamSynchronized music + SFX triggers.
## Present now so the autoload contract from Stage 0 is stable.

var enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
