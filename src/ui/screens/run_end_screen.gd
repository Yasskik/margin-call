class_name RunEndScreen
extends Control
## GAME OVER / VICTORY receipt with run stats and NEW RUN.

signal new_run_pressed

const OUTCOME_TEXT: Dictionary = {
	"VICTORY": ["YOU OWN THE STREET", "Twelve audits cleared. The SEC is still looking for the paperwork."],
	"MARGIN_CALL": ["MARGIN CALL", "Equity hit zero. The risk desk liquidated everything, including your dignity."],
	"INSOLVENCY": ["INSOLVENT", "You missed the quarterly target. The partners changed the locks."],
	"BURNOUT": ["BURNOUT", "Stress maxed out. You are now a wellness influencer."],
	"INDICTED": ["INDICTED", "Five stars of SEC heat. Orange is the new navy."],
}


func show_end(outcome: String, stats: Dictionary) -> void:
	for c: Node in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self, 0.86)
	var win: bool = outcome == "VICTORY"
	var accent: Color = ThemeTokens.LUXURY_GOLD if win else ThemeTokens.MARGIN_CRIMSON
	var box: VBoxContainer = UiKit.center_panel(self, 820, accent)
	var txt: Array = OUTCOME_TEXT.get(outcome, [outcome, ""])
	UiKit.title(box, str(txt[0]), accent, 80)
	UiKit.caption(box, str(txt[1]), ThemeTokens.TEXT_IVORY, 22)
	UiKit.rule(box)
	UiKit.kv_row(box, "Reached", "Quarter %d" % int(stats.get("quarter", 1)), ThemeTokens.TEXT_IVORY, 28)
	UiKit.kv_row(box, "Final equity", ThemeTokens.format_currency(float(stats.get("final_equity", 0.0))), accent, 28)
	UiKit.kv_row(box, "Peak equity", ThemeTokens.format_currency(float(stats.get("peak_equity", 0.0))), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Sessions traded", str(int(stats.get("sessions", 0))))
	UiKit.kv_row(box, "Walls + floors broken", str(int(stats.get("walls", 0))), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Best combo", ThemeTokens.format_currency(float(stats.get("best_combo", 0.0)), 0, true), ThemeTokens.LUXURY_GOLD)
	UiKit.kv_row(box, "Taxes / burn paid", "%s / %s" % [ThemeTokens.format_currency(float(stats.get("taxes_paid", 0.0))), ThemeTokens.format_currency(float(stats.get("burn_paid", 0.0)))], ThemeTokens.TEXT_MUTED, 20)
	UiKit.kv_row(box, "Seed", str(int(stats.get("seed", 0))), ThemeTokens.TEXT_MUTED, 18)
	UiKit.rule(box)
	box.add_child(UiKit.button("NEW RUN  ▸  [ENTER]", accent, func() -> void: new_run_pressed.emit(), 28))
	UiKit.pop_in(self)
	EventBus.screen_shake_requested.emit(8.0 if win else 20.0, 0.4)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and is_visible_in_tree() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		new_run_pressed.emit()
