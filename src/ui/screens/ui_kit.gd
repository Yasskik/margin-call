class_name UiKit
extends RefCounted
## Small layout helpers shared by the Stage 4A overlays and screens (all styling via ThemeTokens).


static func backdrop(parent: Control, alpha: float = 0.74) -> ColorRect:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(ThemeTokens.BG_DEEP_NAVY, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	return dim


## CenterContainer > glass PanelContainer (accent border) > margins > VBox. Returns the VBox.
static func center_panel(parent: Control, width: float, accent: Color) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.94, accent, 16, 2))
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(m)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	m.add_child(box)
	return box


static func title(parent: Container, text: String, col: Color, size: int = 52) -> Label:
	var l: Label = ThemeTokens.make_label(text, size, col, true, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func caption(parent: Container, text: String, col: Color = ThemeTokens.TEXT_MUTED, size: int = 20) -> Label:
	var l: Label = ThemeTokens.make_label(text, size, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func kv_row(parent: Container, key: String, value: String, col: Color = ThemeTokens.TEXT_IVORY, size: int = 24) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	var k: Label = ThemeTokens.make_label(key, size, ThemeTokens.TEXT_MUTED, false)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v: Label = ThemeTokens.make_label(value, size, col, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	parent.add_child(row)
	return v


static func rule(parent: Container, col: Color = ThemeTokens.BORDER_HAIRLINE) -> void:
	var r: ColorRect = ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)


static func button(text: String, accent: Color, cb: Callable, size: int = 24, filled: bool = true) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	ThemeTokens.style_button(b, accent, size, filled)
	b.pressed.connect(cb)
	return b


static func progress(parent: Container, ratio: float, col: Color) -> void:
	var track: PanelContainer = PanelContainer.new()
	track.add_theme_stylebox_override("panel", ThemeTokens.create_pill_stylebox(Color(ThemeTokens.BG_DEEP_NAVY, 0.9), ThemeTokens.BORDER_HAIRLINE, 6))
	track.custom_minimum_size = Vector2(0, 18)
	parent.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.color = col
	fill.custom_minimum_size = Vector2(0, 12)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_child(fill)
	track.resized.connect(func() -> void: fill.custom_minimum_size.x = maxf(0.0, (track.size.x - 6.0) * clampf(ratio, 0.0, 1.0)))


## Scale + fade "pop in" for a freshly shown overlay.
static func pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = c.size * 0.5
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
