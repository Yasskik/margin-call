extends Control
## Stage 0 placeholder: Navy/Gold diagnostic screen listing loaded JSON counts.


func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = ThemeTokens.BG_DEEP_NAVY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	box.add_child(ThemeTokens.make_label("MARGIN CALL — SYSTEM ONLINE", 64, ThemeTokens.LUXURY_GOLD, true, true))
	var counts: Dictionary = DataRegistry.counts()
	for key: String in counts.keys():
		box.add_child(ThemeTokens.make_label("%-20s %4d" % [key, int(counts[key])], 26, ThemeTokens.TEXT_IVORY))
	var ok: bool = DataRegistry.loader.is_valid()
	box.add_child(ThemeTokens.make_label("DATA REGISTRY: " + ("VALID" if ok else "ERRORS"), 28, ThemeTokens.PROFIT_EMERALD if ok else ThemeTokens.MARGIN_CRIMSON, true))
