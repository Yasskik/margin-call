extends Node
## Thin autoload wrapper holding one DataLoader for the UI (Rule 1.1 #7).
## Tests and the balance simulator construct DataLoader directly instead.

var loader: DataLoader


func _ready() -> void:
	loader = DataLoader.new()
	loader.load_all("res://data/")
	if not loader.is_valid():
		for err: String in loader.errors:
			push_error("DataRegistry: " + err)


func counts() -> Dictionary:
	return loader.counts()
