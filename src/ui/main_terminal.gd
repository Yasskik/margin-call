class_name MainTerminal
extends Control
## Live 45-second trading terminal. Layout + wiring only: all numbers come from the sim through
## RunController reads and EventBus signals (AGENTS.md 1.1 #2).

var run: RunController
var top_bar: TerminalTopBar
var tickers: TickerList
var chart: ChartCanvas
var trade: TradePanel
var gauges: RiskGauges
var tray: PerkTray
var paused: bool = false
var hold: bool = false ## set while a Boss banner / overlay owns the screen
var speed: float = 1.0
var _acc: float = 0.0
var _hitstop: float = 0.0
var _chart_title: Label
var _chart_role: Label
var _headline: Label


func build(r: RunController) -> void:
	run = r
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	top_bar = TerminalTopBar.new()
	top_bar.build()
	top_bar.pause_pressed.connect(toggle_pause)
	root.add_child(top_bar)
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	root.add_child(mid)
	tickers = TickerList.new()
	mid.add_child(_glass(tickers, Vector2(270, 0)))
	mid.add_child(_build_chart_panel())
	trade = TradePanel.new()
	mid.add_child(_glass(trade, Vector2(450, 0)))
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.custom_minimum_size = Vector2(0, 256)
	root.add_child(bottom)
	gauges = RiskGauges.new()
	bottom.add_child(_glass(gauges, Vector2(560, 0)))
	tray = PerkTray.new()
	var tray_panel: PanelContainer = _glass(tray, Vector2(0, 0))
	tray_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(tray_panel)
	trade.build(run)
	tickers.ticker_selected.connect(_on_ticker_selected)
	EventBus.wall_smashed.connect(func(_t: String, _k: int, _p: float, _b: float, _m: float) -> void: _hitstop = 0.06)
	EventBus.jump_event_announced.connect(_on_jump_headline)
	EventBus.margin_called.connect(func(eq: float) -> void:
		_headline.text = "MARGIN CALL — book force-liquidated (2%% slippage). Equity %s" % ThemeTokens.format_currency(eq)
		_headline.add_theme_color_override("font_color", ThemeTokens.MARGIN_CRIMSON))


func bind_session(s: SessionRunner) -> void:
	chart.session = s
	gauges.session = s
	if tickers.session == null:
		tickers.build(s)
	else:
		tickers.session = s


func _build_chart_panel() -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var hdr: HBoxContainer = HBoxContainer.new()
	_chart_title = ThemeTokens.make_label("OMNI", 30, ThemeTokens.TEXT_IVORY, true)
	_chart_role = ThemeTokens.make_label("", 17, ThemeTokens.TEXT_MUTED)
	_chart_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(_chart_title)
	hdr.add_child(_chart_role)
	box.add_child(hdr)
	chart = ChartCanvas.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(chart)
	_headline = ThemeTokens.make_label("TAPE OPEN · Leverage 2x+ to light up Resistance Walls", 18, ThemeTokens.TEXT_MUTED, true)
	_headline.clip_text = true
	box.add_child(_headline)
	var p: PanelContainer = _glass(box, Vector2.ZERO)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _glass(child: Control, min_size: Vector2) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox())
	p.custom_minimum_size = min_size
	child.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(child)
	return p


func _on_ticker_selected(t: String) -> void:
	chart.set_ticker(t)
	trade.set_ticker(t)
	var s: StockDef = run.data.get_stock(t)
	_chart_title.text = "%s  " % t
	_chart_role.text = "%s · σ %.0f%% · %s" % [s.name, s.base_volatility * 100.0, s.role]


func _on_jump_headline(t: String, headline: String, impact: float) -> void:
	_headline.text = "BREAKING  %s  (%s %s)" % [headline.to_upper(), t, ThemeTokens.format_pct(impact, 1, true)]
	_headline.add_theme_color_override("font_color", ThemeTokens.PROFIT_EMERALD if impact >= 0.0 else ThemeTokens.MARGIN_CRIMSON)


func toggle_pause() -> void:
	paused = not paused


func _process(delta: float) -> void:
	if run == null or run.session == null:
		return
	top_bar.update_view(run.get_hud_info(), paused)
	if paused or hold or run.phase != "TRADING":
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	var tick_len: float = 1.0 / float(run.data.sim_config["ticks_per_second"])
	_acc += delta * speed
	var guard: int = 0
	while _acc >= tick_len and run.phase == "TRADING" and guard < 8:
		_acc -= tick_len
		run.advance_tick()
		guard += 1


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree() or hold or run.phase != "TRADING":
		return
	match k.keycode:
		KEY_SPACE:
			toggle_pause()
		KEY_Q:
			trade.open_side("LONG")
		KEY_W:
			trade.open_side("SHORT")
		KEY_A:
			trade.set_leverage(1)
		KEY_S:
			trade.set_leverage(2)
		KEY_D:
			trade.set_leverage(5)
		KEY_F:
			trade.set_leverage(10)
		KEY_X:
			trade.close_selected()
		_:
			var n: int = k.keycode - KEY_1
			if n >= 0 and n < run.data.stocks.size():
				tickers.select(run.data.stocks[n].ticker)
	get_viewport().set_input_as_handled()
