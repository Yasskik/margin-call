class_name BossIntroBanner
extends Control
## Siren banner announcing the Quarterly Boss. Holds the tape (terminal.hold) until dismissed
## or 3.2 s elapse.

signal dismissed

const HOLD_SECONDS: float = 3.2

var _t: float = 0.0
var _scroll: float = 0.0
var _active: bool = false
var _stripe_top: Label
var _stripe_bot: Label
var _siren: ColorRect


func announce(boss: Dictionary, target: float, burn: float) -> void:
	for c: Node in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_siren = ColorRect.new()
	_siren.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_siren.color = Color(ThemeTokens.MARGIN_CRIMSON, 0.0)
	_siren.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_siren)
	var band: PanelContainer = PanelContainer.new()
	band.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.96, ThemeTokens.MARGIN_CRIMSON, 0, 3))
	band.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	band.anchor_right = 1.0
	band.offset_top = -190
	band.offset_bottom = 190
	add_child(band)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	band.add_child(box)
	var strip: String = "  ⚠ QUARTERLY BOSS ⚠  AUDIT AT THE BELL  ".repeat(8)
	_stripe_top = _stripe(box, strip)
	UiKit.caption(box, "QUARTER %d · BOSS SESSION" % int(boss.get("quarter", 1)), ThemeTokens.AMBER, 24)
	UiKit.title(box, str(boss.get("name", "")).to_upper(), ThemeTokens.MARGIN_CRIMSON, 76)
	UiKit.caption(box, str(boss.get("description", "")), ThemeTokens.TEXT_IVORY, 26)
	UiKit.caption(box, "TARGET %s NET  ·  BURN %s  ·  [ENTER] TO TRADE" % [ThemeTokens.format_currency(target), ThemeTokens.format_currency(burn)], ThemeTokens.LUXURY_GOLD, 22)
	_stripe_bot = _stripe(box, strip)
	_t = 0.0
	_active = true
	visible = true
	band.scale = Vector2(1.0, 0.0)
	band.pivot_offset = Vector2(960, 190)
	var tw: Tween = band.create_tween()
	tw.tween_property(band, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.screen_shake_requested.emit(14.0, 0.4)


func _stripe(parent: Container, txt: String) -> Label:
	var l: Label = ThemeTokens.make_label(txt, 22, ThemeTokens.BG_DEEP_NAVY, true)
	l.clip_text = true
	var bg: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = ThemeTokens.AMBER
	bg.add_theme_stylebox_override("panel", sb)
	bg.clip_contents = true
	bg.add_child(l)
	parent.add_child(bg)
	return l


func is_active() -> bool:
	return _active


func dismiss() -> void:
	if not _active:
		return
	_active = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		dismissed.emit())


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_siren.color.a = 0.18 * (0.5 + 0.5 * sin(_t * 12.0))
	_scroll += delta * 18.0
	while _scroll >= 1.0:
		_scroll -= 1.0
		_stripe_top.text = _stripe_top.text.substr(1) + _stripe_top.text.substr(0, 1)
		var n: int = _stripe_bot.text.length()
		_stripe_bot.text = _stripe_bot.text.substr(n - 1) + _stripe_bot.text.substr(0, n - 1)
	if _t >= HOLD_SECONDS:
		dismiss()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismiss()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and _active and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		dismiss()
