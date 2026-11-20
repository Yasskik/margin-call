class_name ComboSequencer
extends Control
## Plays Array[TriggerStep] queues left-to-right on the accelerating cadence
##   dt(n) = max(0.08, 0.24 * 0.90^n) / game_speed_mult
## popping the matching JuicyCard, rolling the ALPHA x MULT = TOTAL counter and emitting
## EventBus.combo_step_played with an incrementing pitch_step (Part 3.4).

var tray: PerkTray
var game_speed_mult: float = 1.0
var _queue: Array[Dictionary] = []
var _playing: bool = false
var _panel: PanelContainer
var _title: Label
var _alpha_lbl: Label
var _mult_lbl: Label
var _total_lbl: Label
var _shown_total: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	EventBus.position_closed.connect(_on_position_closed)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.96, ThemeTokens.LUXURY_GOLD, 14, 2))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(v)
	_title = ThemeTokens.make_label("TRADE CLOSED", 20, ThemeTokens.TEXT_MUTED, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_alpha_lbl = _box(row, ThemeTokens.ALGO_CYAN)
	row.add_child(ThemeTokens.make_label("×", 40, ThemeTokens.TEXT_IVORY, true))
	_mult_lbl = _box(row, ThemeTokens.MARGIN_CRIMSON)
	row.add_child(ThemeTokens.make_label("=", 40, ThemeTokens.TEXT_IVORY, true))
	_total_lbl = ThemeTokens.make_label("$0", 48, ThemeTokens.LUXURY_GOLD, true)
	row.add_child(_total_lbl)


func _box(parent: HBoxContainer, col: Color) -> Label:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeTokens.create_pill_stylebox(Color(col, 0.22), col, 10))
	var l: Label = ThemeTokens.make_label("", 38, ThemeTokens.TEXT_IVORY, true)
	l.custom_minimum_size = Vector2(190, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	parent.add_child(p)
	return l


func _on_position_closed(pos_id: String, payout: float, steps: Array) -> void:
	if steps.is_empty():
		return
	enqueue(steps, payout, "TRADE CLOSED · " + pos_id)


func enqueue(steps: Array, total: float, title: String) -> void:
	_queue.append({"steps": steps, "total": total, "title": title})
	if not _playing:
		_play_next()


func is_busy() -> bool:
	return _playing or not _queue.is_empty()


static func step_delay(n: int, speed: float) -> float:
	return maxf(0.08, 0.24 * pow(0.90, float(n))) / speed


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		var tw: Tween = create_tween()
		tw.tween_property(_panel, "modulate:a", 0.0, 0.35).set_delay(0.9)
		return
	_playing = true
	var seq: Dictionary = _queue.pop_front()
	_title.text = str(seq["title"])
	_panel.reset_size()
	_panel.position = Vector2((size.x - _panel.size.x) * 0.5, size.y - 300.0 - _panel.size.y)
	_panel.modulate.a = 1.0
	var alpha: float = 0.0
	var add_total: float = 0.0
	var x_total: float = 1.0
	var n: int = 0
	for s: TriggerStep in seq["steps"]:
		match s.phase:
			"BASE_ALPHA", "FLAT_ALPHA":
				alpha += s.value
			"ADDITIVE_MULT":
				add_total += s.value
			"COMPOUND_XMULT":
				x_total *= s.value
		_alpha_lbl.text = ThemeTokens.format_currency(alpha)
		_mult_lbl.text = "x%.2f" % ((1.0 + add_total) * x_total)
		_roll_total(s.running_total)
		var col: Color = Color(s.color_hex)
		var txt: String = _step_text(s)
		var shake: float = 2.0 + float(n) * 0.6
		var at: Vector2 = tray.pop(s.source_id, txt, col, shake) if tray != null else Vector2(-1, -1)
		if at.x < 0.0:
			FloatingPopup.spawn_global(txt, col, _panel.global_position + Vector2(_panel.size.x * 0.5, -8.0), 30, 70.0)
			EventBus.screen_shake_requested.emit(shake, 0.1)
		EventBus.combo_step_played.emit(s.source_id, txt, s.color_hex, n, shake)
		await get_tree().create_timer(step_delay(n, game_speed_mult)).timeout
		n += 1
	_roll_total(float(seq["total"]))
	EventBus.combo_sequence_finished.emit(float(seq["total"]))
	await get_tree().create_timer(0.35 / game_speed_mult).timeout
	_play_next()


func _roll_total(v: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(func(x: float) -> void:
		_shown_total = x
		_total_lbl.text = ThemeTokens.format_currency(x, 0, x > 0.0)
		_total_lbl.add_theme_color_override("font_color", ThemeTokens.LUXURY_GOLD if x >= 0.0 else ThemeTokens.MARGIN_CRIMSON), _shown_total, v, 0.12)


func _step_text(s: TriggerStep) -> String:
	match s.phase:
		"BASE_ALPHA", "FLAT_ALPHA":
			return "%s %s" % [ThemeTokens.format_currency(s.value, 0, true), s.label]
		"ADDITIVE_MULT":
			return "+%.2fx %s" % [s.value, s.label]
	return "x%.2f %s" % [s.value, s.label]
