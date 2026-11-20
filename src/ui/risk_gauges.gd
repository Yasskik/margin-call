class_name RiskGauges
extends Control
## Live Margin Ratio gauge (zones 15% / 25%) and Kinetic Momentum bar, drawn with _draw().

var session: SessionRunner
var _shown_margin: float = 1.0
var _shown_k: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(520, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if session == null:
		return
	_shown_margin = lerpf(_shown_margin, session.portfolio.margin_ratio(), clampf(delta * 10.0, 0.0, 1.0))
	_shown_k = lerpf(_shown_k, session.momentum.momentum, clampf(delta * 8.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if session == null:
		return
	var f: Font = ThemeTokens.font_mono_bold
	var w: float = size.x
	var safe: float = session.portfolio.margin_safe
	var liq: float = session.portfolio.margin_liquidation
	var scale_max: float = 0.6
	var bar: Rect2 = Rect2(Vector2(0, 34), Vector2(w, 22))
	draw_rect(Rect2(bar.position, Vector2(w * liq / scale_max, bar.size.y)), Color(ThemeTokens.MARGIN_CRIMSON, 0.55))
	draw_rect(Rect2(bar.position + Vector2(w * liq / scale_max, 0), Vector2(w * (safe - liq) / scale_max, bar.size.y)), Color(ThemeTokens.AMBER, 0.5))
	draw_rect(Rect2(bar.position + Vector2(w * safe / scale_max, 0), Vector2(w * (scale_max - safe) / scale_max, bar.size.y)), Color(ThemeTokens.PROFIT_EMERALD, 0.35))
	draw_rect(bar, ThemeTokens.BORDER_HAIRLINE, false, 1.0)
	var flat: bool = session.portfolio.positions.is_empty()
	var m: float = _shown_margin
	var x: float = w * clampf(m, 0.0, scale_max) / scale_max
	var zone: String = session.portfolio.zone_for(m)
	var zcol: Color = ThemeTokens.PROFIT_EMERALD if zone == "SAFE" else (ThemeTokens.AMBER if zone == "WARNING" else ThemeTokens.MARGIN_CRIMSON)
	if not flat:
		draw_rect(Rect2(Vector2(x - 3, bar.position.y - 6), Vector2(6, bar.size.y + 12)), ThemeTokens.TEXT_IVORY)
	var mtxt: String = "MARGIN  FLAT (no exposure)" if flat else "MARGIN  %s  %s" % [ThemeTokens.format_pct(m, 1), zone]
	draw_string(f, Vector2(0, 24), mtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ThemeTokens.TEXT_MUTED if flat else zcol)
	draw_string(ThemeTokens.font_mono, Vector2(w * liq / scale_max - 18, 76), "15%", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ThemeTokens.TEXT_MUTED)
	draw_string(ThemeTokens.font_mono, Vector2(w * safe / scale_max - 18, 76), "25%", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ThemeTokens.TEXT_MUTED)
	var kbar: Rect2 = Rect2(Vector2(0, 112), Vector2(w, 22))
	draw_rect(kbar, Color(ThemeTokens.BG_DEEP_NAVY, 0.8))
	var kw: float = w * _shown_k / 100.0
	draw_rect(Rect2(kbar.position - Vector2(0, 4), Vector2(kw, kbar.size.y + 8)), Color(ThemeTokens.LUXURY_GOLD, 0.18))
	draw_rect(Rect2(kbar.position, Vector2(kw, kbar.size.y)), ThemeTokens.LUXURY_GOLD)
	draw_rect(kbar, ThemeTokens.BORDER_HAIRLINE, false, 1.0)
	var mom: MomentumEngine = session.momentum
	var ktxt: String = "MOMENTUM  K %3d    WALLS %d   FLOORS %d" % [int(_shown_k), mom.session_walls_broken, mom.session_floors_broken]
	draw_string(f, Vector2(0, 102), ktxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ThemeTokens.LUXURY_GOLD)
