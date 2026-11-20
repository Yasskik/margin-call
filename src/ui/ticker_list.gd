class_name TickerList
extends VBoxContainer
## Left rail: 8 ticker rows with live price, session change, held marker and jump-warning flash.

signal ticker_selected(ticker: String)

var session: SessionRunner
var selected: String = ""
var _rows: Dictionary = {}   # ticker -> {panel, price, change, mark, style}
var _warn: Dictionary = {}   # ticker -> seconds left


func build(s: SessionRunner) -> void:
	session = s
	add_theme_constant_override("separation", 4)
	var hdr: Label = ThemeTokens.make_label("WATCHLIST", 18, ThemeTokens.TEXT_MUTED, true)
	add_child(hdr)
	var idx: int = 1
	for st: StockDef in s.market.stocks:
		_add_row(st, idx)
		idx += 1
	EventBus.jump_warning_issued.connect(func(t: String, secs: float, _h: int) -> void: _warn[t] = secs)
	EventBus.jump_event_announced.connect(func(t: String, _h: String, _i: float) -> void: _warn.erase(t))
	select(s.market.stocks[0].ticker)


func _add_row(st: StockDef, idx: int) -> void:
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = ThemeTokens.create_glass_panel_stylebox(0.85, ThemeTokens.BORDER_HAIRLINE, 8)
	sb.set_content_margin_all(6.0)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grid)
	var name_lbl: Label = ThemeTokens.make_label("%d %s" % [idx, st.ticker], 21, ThemeTokens.TEXT_IVORY, true)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var price: Label = ThemeTokens.make_label("0.00", 19, ThemeTokens.TEXT_IVORY)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mark: Label = ThemeTokens.make_label(st.sector.replace("_", "/"), 13, ThemeTokens.TEXT_MUTED)
	var change: Label = ThemeTokens.make_label("+0.00%", 16, ThemeTokens.PROFIT_EMERALD, true)
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for c: Control in [name_lbl, price, mark, change]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(c)
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			select(st.ticker))
	add_child(panel)
	_rows[st.ticker] = {"panel": panel, "price": price, "change": change, "mark": mark, "style": sb, "sector": st.sector.replace("_", "/")}


func select(t: String) -> void:
	selected = t
	ticker_selected.emit(t)


func _process(delta: float) -> void:
	if session == null:
		return
	var held: Array[String] = session.portfolio.held_tickers()
	var blink: bool = fmod(Time.get_ticks_msec() / 110.0, 2.0) < 1.0
	for t: String in _rows.keys():
		var row: Dictionary = _rows[t]
		var px: float = float(session.market.prices[t])
		(row["price"] as Label).text = "%.2f" % px if px < 1000.0 else "%.1f" % px
		var ch: float = session.market.session_return(t)
		var ch_lbl: Label = row["change"]
		ch_lbl.text = ThemeTokens.format_pct(ch, 2, true)
		ch_lbl.add_theme_color_override("font_color", ThemeTokens.PROFIT_EMERALD if ch >= 0.0 else ThemeTokens.MARGIN_CRIMSON)
		var mark: Label = row["mark"]
		mark.text = ("● " if held.has(t) else "") + str(row["sector"])
		mark.add_theme_color_override("font_color", ThemeTokens.LUXURY_GOLD if held.has(t) else ThemeTokens.TEXT_MUTED)
		var sb: StyleBoxFlat = row["style"]
		var warn_left: float = float(_warn.get(t, 0.0))
		if warn_left > 0.0:
			_warn[t] = warn_left - delta
			sb.bg_color = Color(ThemeTokens.AMBER, 0.45) if blink else Color(ThemeTokens.MARGIN_CRIMSON, 0.35)
			sb.border_color = ThemeTokens.AMBER
		else:
			sb.bg_color = Color(ThemeTokens.PANEL_SLATE, 0.95 if t == selected else 0.8)
			sb.border_color = ThemeTokens.LUXURY_GOLD if t == selected else ThemeTokens.BORDER_HAIRLINE
		sb.set_border_width_all(2 if t == selected else 1)
