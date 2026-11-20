class_name TerminalTopBar
extends PanelContainer
## Top HUD strip: wordmark, Quarter/Session/Boss, always-visible Regime Chip, session clock,
## equity / cash / target readouts and the Pause control.

signal pause_pressed

var _quarter_lbl: Label
var _boss_lbl: Label
var _chip: PanelContainer
var _chip_style: StyleBoxFlat
var _chip_lbl: Label
var _odds_lbl: Label
var _clock_lbl: Label
var _equity_lbl: Label
var _cash_lbl: Label
var _target_lbl: Label
var _pause_btn: Button


func build() -> void:
	add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.88, ThemeTokens.BORDER_HAIRLINE, 10))
	custom_minimum_size = Vector2(0, 96)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	add_child(row)
	var logo: Label = ThemeTokens.make_label("MARGIN CALL", 40, ThemeTokens.LUXURY_GOLD, true, true)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(logo)
	var qbox: VBoxContainer = VBoxContainer.new()
	_quarter_lbl = ThemeTokens.make_label("Q1 · SESSION 1/3", 24, ThemeTokens.TEXT_IVORY, true)
	_boss_lbl = ThemeTokens.make_label("", 16, ThemeTokens.TEXT_MUTED)
	qbox.add_child(_quarter_lbl)
	qbox.add_child(_boss_lbl)
	row.add_child(qbox)
	_chip = PanelContainer.new()
	_chip_style = ThemeTokens.create_pill_stylebox(Color(ThemeTokens.ALGO_CYAN, 0.18), ThemeTokens.ALGO_CYAN, 22)
	_chip_style.content_margin_left = 18.0
	_chip_style.content_margin_right = 18.0
	_chip.add_theme_stylebox_override("panel", _chip_style)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_box: VBoxContainer = VBoxContainer.new()
	chip_box.add_theme_constant_override("separation", 0)
	_chip_lbl = ThemeTokens.make_label("● CALM ▲", 24, ThemeTokens.ALGO_CYAN, true)
	_odds_lbl = ThemeTokens.make_label("", 13, ThemeTokens.TEXT_MUTED)
	_odds_lbl.visible = false
	chip_box.add_child(_chip_lbl)
	chip_box.add_child(_odds_lbl)
	_chip.add_child(chip_box)
	row.add_child(_chip)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_clock_lbl = ThemeTokens.make_label("00:45", 44, ThemeTokens.TEXT_IVORY, true)
	row.add_child(_clock_lbl)
	_equity_lbl = _stat(row, "EQUITY")
	_cash_lbl = _stat(row, "FREE CASH")
	_target_lbl = _stat(row, "Q TARGET")
	_pause_btn = Button.new()
	_pause_btn.text = "PAUSE [SPACE]"
	_pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ThemeTokens.style_button(_pause_btn, ThemeTokens.TEXT_MUTED, 18)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_btn)


func _stat(parent: HBoxContainer, title: String) -> Label:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(ThemeTokens.make_label(title, 15, ThemeTokens.TEXT_MUTED, true))
	var v: Label = ThemeTokens.make_label("$0", 30, ThemeTokens.TEXT_IVORY, true)
	box.add_child(v)
	parent.add_child(box)
	return v


func update_view(info: Dictionary, paused: bool) -> void:
	var q: int = int(info["quarter"])
	if bool(info["is_boss"]):
		_quarter_lbl.text = "Q%d · BOSS SESSION" % q
		_quarter_lbl.add_theme_color_override("font_color", ThemeTokens.MARGIN_CRIMSON)
		_boss_lbl.text = str(info["boss_name"]).to_upper()
		_boss_lbl.add_theme_color_override("font_color", ThemeTokens.MARGIN_CRIMSON)
	else:
		_quarter_lbl.text = "Q%d · SESSION %d/%d" % [q, int(info["session_idx"]), int(info["sessions_per_quarter"])]
		_quarter_lbl.add_theme_color_override("font_color", ThemeTokens.TEXT_IVORY)
		_boss_lbl.text = "Boss: " + str(info["boss_name"]) if str(info["boss_name"]) != "" else ""
		_boss_lbl.add_theme_color_override("font_color", ThemeTokens.TEXT_MUTED)
	var regime: String = str(info["regime"])
	var col: Color = ThemeTokens.regime_color(regime)
	var drift: float = float(info["regime_drift"])
	var arrow: String = "▲" if drift > 0.05 else ("▼" if drift < -0.05 else "◆")
	_chip_lbl.text = "● %s %s" % [regime.replace("_", " "), arrow]
	_chip_lbl.add_theme_color_override("font_color", col)
	_chip_style.bg_color = Color(col, 0.18)
	_chip_style.border_color = col
	var odds: Dictionary = info.get("regime_odds", {})
	_odds_lbl.visible = not odds.is_empty()
	if not odds.is_empty():
		_odds_lbl.text = "NEXT: C%d B%d V%d X%d" % [int(float(odds.get("CALM", 0)) * 100), int(float(odds.get("BULL_MANIA", 0)) * 100), int(float(odds.get("VOLATILE", 0)) * 100), int(float(odds.get("CRASH", 0)) * 100)]
	var secs: float = float(info["seconds_left"])
	_clock_lbl.text = "00:%02d" % int(ceil(secs))
	_clock_lbl.add_theme_color_override("font_color", ThemeTokens.MARGIN_CRIMSON if secs <= 10.0 else ThemeTokens.TEXT_IVORY)
	_equity_lbl.text = ThemeTokens.format_compact(float(info["equity"]))
	var eq: float = float(info["equity"])
	var target: float = float(info["target"])
	_equity_lbl.add_theme_color_override("font_color", ThemeTokens.PROFIT_EMERALD if target <= 0.0 or eq >= target else ThemeTokens.TEXT_IVORY)
	_cash_lbl.text = ThemeTokens.format_compact(float(info["cash"]))
	_target_lbl.text = ThemeTokens.format_compact(target) if target > 0.0 else "—"
	_pause_btn.text = "RESUME [SPACE]" if paused else "PAUSE [SPACE]"
