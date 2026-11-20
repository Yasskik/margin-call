class_name SettlementOverlay
extends Control
## End-of-session receipt shown over the terminal once the combo sequencer finishes.

signal continue_pressed

var _btn: Button


func show_summary(run: RunController, s: Dictionary) -> void:
	for c: Node in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self)
	var boss: bool = bool(s.get("is_boss", false))
	var accent: Color = ThemeTokens.MARGIN_CRIMSON if boss else ThemeTokens.LUXURY_GOLD
	var box: VBoxContainer = UiKit.center_panel(self, 760, accent)
	var head: String = "BOSS SESSION SETTLED" if boss else "SESSION SETTLED"
	UiKit.title(box, head, accent, 46)
	UiKit.caption(box, "QUARTER %d · SESSION %d/%d%s" % [int(s["quarter"]), mini(int(s["session_idx"]), 3), 3, "  ·  BOSS" if boss else ""])
	UiKit.rule(box)
	var pnl: float = float(s["session_realized"])
	UiKit.kv_row(box, "Session P&L (realized)", ThemeTokens.format_currency(pnl, 0, true), _pnl_col(pnl), 30)
	var bonus: float = float(s.get("settlement_bonus", 0.0))
	if absf(bonus) > 0.5:
		UiKit.kv_row(box, "Contact settlement bonus", ThemeTokens.format_currency(bonus, 0, true), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Trades closed", str(int(s["trades"])))
	UiKit.kv_row(box, "Walls smashed / floors broken", "%d / %d" % [int(s["walls"]), int(s["floors"])], ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Best combo payout", ThemeTokens.format_currency(float(s["best_combo"]), 0, true), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Lowest margin ratio", ThemeTokens.format_pct(minf(float(s["min_margin"]), 9.99), 1), _margin_col(float(s["min_margin"])))
	if bool(s.get("margin_called", false)):
		UiKit.caption(box, "MARGIN CALL — the desk force-liquidated your book.", ThemeTokens.MARGIN_CRIMSON, 22)
	UiKit.rule(box)
	var eq: float = float(s["equity"])
	var target: float = float(s["target"])
	var info: Dictionary = run.get_hud_info()
	UiKit.kv_row(box, "Equity now", ThemeTokens.format_currency(eq), ThemeTokens.TEXT_IVORY, 30)
	UiKit.kv_row(box, "Quarter target (after burn + tax)", ThemeTokens.format_currency(target), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Burn rate due at audit", "-" + ThemeTokens.format_currency(float(info["burn_rate"])), ThemeTokens.MARGIN_CRIMSON, 20)
	UiKit.kv_row(box, "Est. capital gains tax", "-" + ThemeTokens.format_currency(float(info["est_tax"])), ThemeTokens.MARGIN_CRIMSON, 20)
	var need: float = target + float(info["burn_rate"]) + float(info["est_tax"])
	UiKit.progress(box, eq / maxf(need, 1.0), ThemeTokens.PROFIT_EMERALD if eq >= need else ThemeTokens.AMBER)
	UiKit.caption(box, "%s of the %s you need at the bell" % [ThemeTokens.format_pct(eq / maxf(need, 1.0), 0), ThemeTokens.format_currency(need)], ThemeTokens.TEXT_MUTED, 18)
	_btn = UiKit.button("FACE THE AUDIT  ▸  [ENTER]" if boss else "AFTER-HOURS  ▸  [ENTER]", accent, func() -> void: continue_pressed.emit(), 26)
	box.add_child(_btn)
	UiKit.pop_in(self)


func _pnl_col(v: float) -> Color:
	return ThemeTokens.PROFIT_EMERALD if v >= 0.0 else ThemeTokens.MARGIN_CRIMSON


func _margin_col(m: float) -> Color:
	if m >= 0.25:
		return ThemeTokens.PROFIT_EMERALD
	return ThemeTokens.AMBER if m >= 0.15 else ThemeTokens.MARGIN_CRIMSON


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and is_visible_in_tree() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		continue_pressed.emit()
