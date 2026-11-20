class_name TradePanel
extends VBoxContainer
## Right rail: Long/Short entry, allocation presets, leverage pills, live margin-after preview
## (from PortfolioState.preview_entry, never computed here) and the open-positions book.

var run: RunController
var ticker: String = "OMNI"
var leverage: int = 2
var allocation: float = 0.25
var _lev_buttons: Dictionary = {}
var _alloc_buttons: Dictionary = {}
var _preview_lbl: Label
var _reason_lbl: Label
var _long_btn: Button
var _short_btn: Button
var _book: VBoxContainer
var _rows: Dictionary = {} # pos_id -> Label
var _title: Label


func build(r: RunController) -> void:
	run = r
	add_theme_constant_override("separation", 10)
	_title = ThemeTokens.make_label("ORDER TICKET", 20, ThemeTokens.TEXT_MUTED, true)
	add_child(_title)
	var sides: HBoxContainer = HBoxContainer.new()
	sides.add_theme_constant_override("separation", 10)
	_long_btn = _big_button("LONG  [Q]", ThemeTokens.PROFIT_EMERALD, func() -> void: open_side("LONG"))
	_short_btn = _big_button("SHORT [W]", ThemeTokens.MARGIN_CRIMSON, func() -> void: open_side("SHORT"))
	sides.add_child(_long_btn)
	sides.add_child(_short_btn)
	add_child(sides)
	add_child(ThemeTokens.make_label("ALLOCATION OF EQUITY", 16, ThemeTokens.TEXT_MUTED, true))
	var allocs: HBoxContainer = HBoxContainer.new()
	allocs.add_theme_constant_override("separation", 6)
	for a: Variant in run.data.sim_config.get("allocation_presets", [0.1, 0.25, 0.5, 1.0]):
		var pct: float = float(a)
		var b: Button = _pill("%d%%" % int(round(pct * 100.0)), func() -> void: set_allocation(pct))
		allocs.add_child(b)
		_alloc_buttons[pct] = b
	add_child(allocs)
	add_child(ThemeTokens.make_label("LEVERAGE  [A S D F]", 16, ThemeTokens.TEXT_MUTED, true))
	var levs: HBoxContainer = HBoxContainer.new()
	levs.add_theme_constant_override("separation", 6)
	for l: Variant in run.data.sim_config.get("leverage_options", [1, 2, 3, 5, 10]):
		var lv: int = int(l)
		var b: Button = _pill("%dx" % lv, func() -> void: set_leverage(lv))
		levs.add_child(b)
		_lev_buttons[lv] = b
	add_child(levs)
	var pv: PanelContainer = PanelContainer.new()
	pv.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.9, ThemeTokens.BORDER_HAIRLINE, 8))
	var pv_box: VBoxContainer = VBoxContainer.new()
	pv.add_child(pv_box)
	_preview_lbl = ThemeTokens.make_label("", 20, ThemeTokens.TEXT_IVORY, true)
	_reason_lbl = ThemeTokens.make_label("", 16, ThemeTokens.TEXT_MUTED)
	_reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv_box.add_child(_preview_lbl)
	pv_box.add_child(_reason_lbl)
	add_child(pv)
	var book_hdr: HBoxContainer = HBoxContainer.new()
	var bl: Label = ThemeTokens.make_label("OPEN POSITIONS  [X closes selected]", 16, ThemeTokens.TEXT_MUTED, true)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_hdr.add_child(bl)
	add_child(book_hdr)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book = VBoxContainer.new()
	_book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book.add_theme_constant_override("separation", 6)
	scroll.add_child(_book)
	add_child(scroll)
	EventBus.position_opened.connect(func(_a: String, _b: String, _c: String, _d: int, _e: float) -> void: _rebuild_book())
	EventBus.position_closed.connect(func(_a: String, _b: float, _c: Array) -> void: _rebuild_book())
	set_leverage(leverage)
	set_allocation(allocation)


func _big_button(txt: String, col: Color, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeTokens.style_button(b, col, 24, true)
	b.pressed.connect(cb)
	return b


func _pill(txt: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeTokens.style_button(b, ThemeTokens.LUXURY_GOLD, 19)
	b.pressed.connect(cb)
	return b


func set_ticker(t: String) -> void:
	ticker = t


func set_leverage(l: int) -> void:
	if run.session != null and not run.session.portfolio.allowed_leverages().has(l):
		return
	leverage = l
	_refresh_pills()


func set_allocation(a: float) -> void:
	allocation = a
	_refresh_pills()


func _refresh_pills() -> void:
	for l: int in _lev_buttons.keys():
		var b: Button = _lev_buttons[l]
		var allowed: bool = run.session == null or run.session.portfolio.allowed_leverages().has(l)
		b.disabled = not allowed
		b.text = ("%dx" % l) if allowed else ("%dx LOCK" % l)
		ThemeTokens.style_button(b, ThemeTokens.LUXURY_GOLD, 19, l == leverage)
	for a: float in _alloc_buttons.keys():
		ThemeTokens.style_button(_alloc_buttons[a], ThemeTokens.ALGO_CYAN, 19, is_equal_approx(a, allocation))


func open_side(side: String) -> void:
	var res: Dictionary = run.open_position(ticker, side, leverage, allocation)
	if not bool(res.get("ok", false)):
		FloatingPopup.spawn_global(str(res.get("reason", "Rejected")), ThemeTokens.MARGIN_CRIMSON, global_position + Vector2(size.x * 0.5, 40), 26, 50.0)


func close_selected() -> void:
	if run.session == null:
		return
	for p: PositionState in run.session.portfolio.positions:
		if p.ticker == ticker:
			run.close_position(p.id)
			return


func _rebuild_book() -> void:
	for c: Node in _book.get_children():
		c.queue_free()
	_rows.clear()
	if run.session == null:
		return
	for p: PositionState in run.session.portfolio.positions:
		var row: HBoxContainer = HBoxContainer.new()
		var lbl: Label = ThemeTokens.make_label("", 18, ThemeTokens.TEXT_IVORY, true)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var b: Button = Button.new()
		b.text = "CLOSE"
		ThemeTokens.style_button(b, ThemeTokens.LUXURY_GOLD, 17)
		var pid: String = p.id
		b.pressed.connect(func() -> void: run.close_position(pid))
		row.add_child(b)
		_book.add_child(row)
		_rows[p.id] = lbl


func _process(_delta: float) -> void:
	if run == null or run.session == null:
		return
	var pv: Dictionary = run.preview_entry(ticker, "LONG", leverage, allocation)
	var z: String = str(pv["zone"])
	var zcol: Color = ThemeTokens.PROFIT_EMERALD if z == "SAFE" else (ThemeTokens.AMBER if z == "WARNING" else ThemeTokens.MARGIN_CRIMSON)
	_preview_lbl.text = "%s  %dx  %s → M %s" % [ticker, leverage, ThemeTokens.format_currency(float(pv["notional"])), ThemeTokens.format_pct(float(pv["margin_after"]), 1)]
	_preview_lbl.add_theme_color_override("font_color", zcol)
	var reason: String = str(pv["reason"])
	_reason_lbl.text = ("ZONE %s · %s" % [z, reason]) if reason != "OK" else "ZONE SAFE · collateral %s" % ThemeTokens.format_currency(float(pv["collateral"]))
	var open: bool = run.session.active
	_long_btn.disabled = not open
	_short_btn.disabled = not open or not run.session.portfolio.shorts_enabled
	for p: PositionState in run.session.portfolio.positions:
		if _rows.has(p.id):
			var pnl: float = p.base_alpha()
			var l: Label = _rows[p.id]
			l.text = "%s %s %dx  %s" % [p.ticker, "L" if p.is_long() else "S", p.leverage, ThemeTokens.format_currency(pnl, 0, true)]
			l.add_theme_color_override("font_color", ThemeTokens.PROFIT_EMERALD if pnl >= 0.0 else ThemeTokens.MARGIN_CRIMSON)
