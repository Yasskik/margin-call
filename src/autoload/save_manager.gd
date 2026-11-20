extends Node
## Stage 7 placeholder: atomic versioned JSON saves (user://margin_call_save.json / _meta.json).

const SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://margin_call_save.json"
const META_PATH: String = "user://margin_call_meta.json"


func has_active_run() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
