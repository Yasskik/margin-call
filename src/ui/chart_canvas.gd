class_name ChartCanvas
extends Control
## Custom _draw() live candlestick + glowing area-line chart with entry lines, live PnL tags and
## gold Resistance Wall / crimson Support Floor laser lines that shatter into particles.

const VISIBLE_CANDLES: int = 96
const PAD_RIGHT: float = 120.0
const PAD_TOP: float = 24.0
const PAD_BOTTOM: float = 16.0

var session: SessionRunner
var ticker: String = "OMNI"
var _particles: Array[Dictionary] = []
var _flash: float = 0.0
var _warn_left: float = 0.0
var _warn_hint: int = 0
var _jump_flash: float = 0.0
var _lo: float = 0.0
var _hi: float = 1.0
var _plot: Rect2 = Rect2()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.wall_smashed.connect(_on_wall_smashed)
	EventBus.jump_warning_issued.connect(_on_jump_warning)
	EventBus.jump_event_announced.connect(_on_jump)


func set_ticker(t: String) -> void:
	ticker = t
	_warn_left = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	_jump_flash = maxf(0.0, _jump_flash - delta * 2.0)
	_warn_left = maxf(0.0, _warn_left - delta)
	for p: Dictionary in _particles:
		p["vel"] = (p["vel"] as Vector2) + Vector2(0, 520.0) * delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = float(p["life"]) - delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	queue_redraw()


func _y(price: float) -> float:
	return _plot.position.y + _plot.size.y * (1.0 - (price - _lo) / maxf(_hi - _lo, 1e-9))


func _visible_candles() -> Array:
	var list: Array = (session.market.candles[ticker] as Array).duplicate()
	var b: Dictionary = session.market.building_candle(ticker)
	if not b.is_empty():
		list.append(b)
	if list.size() > VISIBLE_CANDLES:
		list = list.slice(list.size() - VISIBLE_CANDLES)
	return list


func _draw() -> void:
	if session == null:
		return
	_plot = Rect2(Vector2(8.0, PAD_TOP), Vector2(size.x - PAD_RIGHT - 8.0, size.y - PAD_TOP - PAD_BOTTOM))
	var candles: Array = _visible_candles()
	if candles.is_empty():
		return
	_compute_range(candles)
	var font: Font = ThemeTokens.font_mono
	var regime_col: Color = ThemeTokens.regime_color(session.market.regime)
	for i: int in 6:
		var price: float = lerpf(_lo, _hi, float(i) / 5.0)
		var y: float = _y(price)
		draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), Color(ThemeTokens.BORDER_HAIRLINE, 0.55), 1.0)
		draw_string(font, Vector2(_plot.end.x + 10.0, y + 6.0), _fmt_price(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ThemeTokens.TEXT_MUTED)
	var w: float = _plot.size.x / float(VISIBLE_CANDLES)
	var line_pts: PackedVector2Array = PackedVector2Array()
	for i: int in candles.size():
		var c: Dictionary = candles[i]
		var x: float = _plot.position.x + w * (float(i) + 0.5)
		var up: bool = float(c["c"]) >= float(c["o"])
		var col: Color = ThemeTokens.PROFIT_EMERALD if up else ThemeTokens.MARGIN_CRIMSON
		draw_line(Vector2(x, _y(float(c["h"]))), Vector2(x, _y(float(c["l"]))), Color(col, 0.85), 1.5)
		var top: float = _y(maxf(float(c["o"]), float(c["c"])))
		var bot: float = _y(minf(float(c["o"]), float(c["c"])))
		draw_rect(Rect2(x - w * 0.34, top, w * 0.68, maxf(bot - top, 2.0)), col)
		line_pts.append(Vector2(x, _y(float(c["c"]))))
	if line_pts.size() >= 2:
		var fill: PackedVector2Array = line_pts.duplicate()
		fill.append(Vector2(line_pts[line_pts.size() - 1].x, _plot.end.y))
		fill.append(Vector2(line_pts[0].x, _plot.end.y))
		draw_colored_polygon(fill, Color(regime_col, 0.07))
		draw_polyline(line_pts, Color(regime_col, 0.16), 8.0, true)
		draw_polyline(line_pts, Color(regime_col, 0.85), 2.0, true)
	_draw_positions(font)
	_draw_last_price(font, line_pts)
	for p: Dictionary in _particles:
		var a: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		draw_rect(Rect2(p["pos"] as Vector2, Vector2(float(p["size"]), float(p["size"]) * 0.5)), Color(p["color"] as Color, a))
	if _flash > 0.0:
		draw_rect(_plot, Color(ThemeTokens.LUXURY_GOLD, _flash * 0.16))
	if _jump_flash > 0.0:
		draw_rect(_plot, Color(ThemeTokens.TEXT_IVORY, _jump_flash * 0.10))
	if _warn_left > 0.0:
		_draw_warning(font)


func _compute_range(candles: Array) -> void:
	var lo: float = INF
	var hi: float = -INF
	for c: Dictionary in candles:
		lo = minf(lo, float(c["l"]))
		hi = maxf(hi, float(c["h"]))
	for p: PositionState in session.portfolio.positions:
		if p.ticker != ticker:
			continue
		lo = minf(lo, p.entry_mid)
		hi = maxf(hi, p.entry_mid)
		var lad: Dictionary = session.momentum.get_ladder(p.id)
		if not lad.is_empty() and int(lad["next"]) < (lad["prices"] as Array).size():
			var nxt: float = float((lad["prices"] as Array)[int(lad["next"])])
			lo = minf(lo, nxt)
			hi = maxf(hi, nxt)
	var pad: float = maxf((hi - lo) * 0.08, hi * 0.002)
	_lo = lo - pad
	_hi = hi + pad


func _draw_positions(font: Font) -> void:
	for p: PositionState in session.portfolio.positions:
		if p.ticker != ticker:
			continue
		var side_col: Color = ThemeTokens.PROFIT_EMERALD if p.is_long() else ThemeTokens.MARGIN_CRIMSON
		var lad: Dictionary = session.momentum.get_ladder(p.id)
		if not lad.is_empty():
			var prices: Array = lad["prices"]
			var wall_col: Color = ThemeTokens.LUXURY_GOLD if p.is_long() else ThemeTokens.MARGIN_CRIMSON
			for k: int in range(int(lad["next"]), prices.size()):
				var wy: float = _y(float(prices[k]))
				if wy < _plot.position.y - 2.0 or wy > _plot.end.y + 2.0:
					continue
				var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0 + float(k))
				draw_line(Vector2(_plot.position.x, wy), Vector2(_plot.end.x, wy), Color(wall_col, 0.18 * pulse), 9.0)
				draw_line(Vector2(_plot.position.x, wy), Vector2(_plot.end.x, wy), Color(wall_col, 0.95), 2.0)
				var lbl: String = ("WALL %d" if p.is_long() else "FLOOR %d") % (k + 1)
				draw_string(font, Vector2(_plot.position.x + 8.0, wy - 7.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, wall_col)
		var ey: float = _y(p.entry_mid)
		draw_dashed_line(Vector2(_plot.position.x, ey), Vector2(_plot.end.x, ey), Color(side_col, 0.8), 1.5, 10.0)
		var pnl: float = p.base_alpha()
		var tag: String = "%s %dx  %s" % [p.side, p.leverage, ThemeTokens.format_currency(pnl, 0, true)]
		var tag_col: Color = ThemeTokens.PROFIT_EMERALD if pnl >= 0.0 else ThemeTokens.MARGIN_CRIMSON
		var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16.0
		var r: Rect2 = Rect2(Vector2(_plot.end.x - tw - 8.0, ey - 26.0), Vector2(tw, 24.0))
		draw_rect(r, Color(ThemeTokens.BG_DEEP_NAVY, 0.9))
		draw_rect(r, tag_col, false, 1.0)
		draw_string(font, r.position + Vector2(8.0, 18.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tag_col)


func _draw_last_price(font: Font, pts: PackedVector2Array) -> void:
	if pts.is_empty():
		return
	var mid: float = float(session.market.prices[ticker])
	var y: float = clampf(_y(mid), _plot.position.y, _plot.end.y)
	var up: bool = session.market.session_return(ticker) >= 0.0
	var col: Color = ThemeTokens.PROFIT_EMERALD if up else ThemeTokens.MARGIN_CRIMSON
	var r: Rect2 = Rect2(Vector2(_plot.end.x + 4.0, y - 14.0), Vector2(PAD_RIGHT - 8.0, 28.0))
	draw_rect(r, col)
	draw_string(ThemeTokens.font_mono_bold, r.position + Vector2(6.0, 20.0), _fmt_price(mid), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ThemeTokens.BG_DEEP_NAVY)
	draw_circle(pts[pts.size() - 1], 5.0, col)


func _draw_warning(font: Font) -> void:
	var on: bool = int(Time.get_ticks_msec() / 120) % 2 == 0
	var dir: String = "" if _warn_hint == 0 else ("  ▲ UP" if _warn_hint > 0 else "  ▼ DOWN")
	var txt: String = "⚠ CATALYST INBOUND %.1fs%s" % [_warn_left, dir]
	var col: Color = ThemeTokens.AMBER if on else ThemeTokens.MARGIN_CRIMSON
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	var pos: Vector2 = Vector2(_plot.position.x + (_plot.size.x - sz.x) * 0.5, _plot.position.y + 46.0)
	draw_rect(Rect2(pos - Vector2(14, 34), sz + Vector2(28, 14)), Color(ThemeTokens.BG_DEEP_NAVY, 0.85))
	draw_rect(Rect2(pos - Vector2(14, 34), sz + Vector2(28, 14)), col, false, 2.0)
	draw_string(ThemeTokens.font_mono_bold, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)


func _fmt_price(p: float) -> String:
	return "%.2f" % p if p < 1000.0 else "%.1f" % p


func _on_wall_smashed(t: String, tier: int, wall_price: float, bonus: float, _m: float) -> void:
	if t != ticker or session == null:
		return
	var y: float = _y(wall_price)
	for i: int in 70:
		var x: float = _plot.position.x + randf() * _plot.size.x
		_particles.append({
			"pos": Vector2(x, y), "vel": Vector2(randf_range(-160, 160), randf_range(-420, -60)),
			"life": randf_range(0.5, 1.1), "max": 1.1, "size": randf_range(4.0, 10.0),
			"color": ThemeTokens.LUXURY_GOLD if randf() < 0.75 else ThemeTokens.TEXT_IVORY,
		})
	_flash = 1.0
	var gp: Vector2 = get_global_transform() * Vector2(_plot.get_center().x, clampf(y, 80.0, size.y - 40.0))
	FloatingPopup.spawn_global("WALL %d SMASHED  %s" % [tier, ThemeTokens.format_currency(bonus, 0, true)], ThemeTokens.LUXURY_GOLD, gp, 44, 110.0)


func _on_jump_warning(t: String, seconds_ahead: float, hint: int) -> void:
	if t == ticker:
		_warn_left = seconds_ahead
		_warn_hint = hint


func _on_jump(t: String, _headline: String, _impact: float) -> void:
	if t == ticker:
		_jump_flash = 1.0
		_warn_left = 0.0
