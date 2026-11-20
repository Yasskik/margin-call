class_name TitleScreen
extends Control
## Minimal MENU screen: logo, tagline, controls cheat-sheet and START.

signal start_pressed


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self, 0.35)
	var box: VBoxContainer = UiKit.center_panel(self, 980, ThemeTokens.LUXURY_GOLD)
	box.add_theme_constant_override("separation", 14)
	var logo: Label = UiKit.title(box, "MARGIN CALL", ThemeTokens.LUXURY_GOLD, 104)
	logo.pivot_offset = Vector2(450, 60)
	UiKit.caption(box, "A HIGH-LEVERAGE TRADING ROGUELIKE", ThemeTokens.TEXT_IVORY, 26)
	UiKit.caption(box, "Survive twelve quarterly audits. Smash resistance walls. Chain your Contacts into obscene combos.\nOne bad candle and the desk liquidates you.", ThemeTokens.TEXT_MUTED, 20)
	UiKit.rule(box, Color(ThemeTokens.LUXURY_GOLD, 0.4))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	for pair: Array in [["1-8", "Select ticker"], ["Q / W", "Open LONG / SHORT"], ["A S D F", "Leverage 1x 2x 5x 10x"], ["X", "Close selected ticker"], ["SPACE", "Pause the tape"], ["R / ENTER", "Reroll / continue (shop)"]]:
		var k: Label = ThemeTokens.make_label(str(pair[0]), 20, ThemeTokens.ALGO_CYAN, true)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		grid.add_child(ThemeTokens.make_label(str(pair[1]), 20, ThemeTokens.TEXT_IVORY, false))
	box.add_child(grid)
	UiKit.rule(box, Color(ThemeTokens.LUXURY_GOLD, 0.4))
	box.add_child(UiKit.button("OPEN THE DESK  ▸  [ENTER]", ThemeTokens.LUXURY_GOLD, func() -> void: start_pressed.emit(), 30))
	UiKit.caption(box, "Vertical slice · Quarters 1-4 · Contacts shop live · Lifestyle & Shady Deals coming soon", ThemeTokens.TEXT_MUTED, 16)
	var tw: Tween = logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.025, 1.025), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and is_visible_in_tree() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		start_pressed.emit()
