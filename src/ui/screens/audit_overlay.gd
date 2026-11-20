class_name AuditOverlay
extends Control
## Quarterly Boss audit: equity - burn - tax vs target, with a PASS / INSOLVENT stamp.

signal continue_pressed


func show_audit(a: Dictionary, tax_rate: float) -> void:
	for c: Node in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self, 0.82)
	var passed: bool = bool(a["passed"])
	var accent: Color = ThemeTokens.PROFIT_EMERALD if passed else ThemeTokens.MARGIN_CRIMSON
	var box: VBoxContainer = UiKit.center_panel(self, 760, accent)
	UiKit.title(box, "QUARTERLY AUDIT", ThemeTokens.LUXURY_GOLD, 48)
	UiKit.caption(box, "Q%d BOSS · %s" % [int(a["quarter"]), str(a["boss_name"]).to_upper()], ThemeTokens.TEXT_MUTED, 22)
	UiKit.rule(box)
	UiKit.kv_row(box, "Equity at the closing bell", ThemeTokens.format_currency(float(a["equity_before"])), ThemeTokens.TEXT_IVORY, 28)
	UiKit.kv_row(box, "− Lifestyle burn rate", "-" + ThemeTokens.format_currency(float(a["burn"])), ThemeTokens.MARGIN_CRIMSON)
	UiKit.kv_row(box, "− Capital gains tax (%d%%)" % int(round(tax_rate * 100.0)), "-" + ThemeTokens.format_currency(float(a["tax"])), ThemeTokens.MARGIN_CRIMSON)
	UiKit.rule(box)
	UiKit.kv_row(box, "= Net equity", ThemeTokens.format_currency(float(a["net"])), accent, 34)
	UiKit.kv_row(box, "Target equity", ThemeTokens.format_currency(float(a["target"])), ThemeTokens.LUXURY_GOLD, 28)
	var stamp: Label = ThemeTokens.make_label("AUDIT PASSED" if passed else "INSOLVENT", 72, accent, true, true)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.custom_minimum_size = Vector2(0, 110)
	box.add_child(stamp)
	UiKit.caption(box, str(a["reason"]), accent, 20)
	var label: String = "NEXT QUARTER  ▸  [ENTER]" if passed else "READ THE RECEIPT  ▸  [ENTER]"
	box.add_child(UiKit.button(label, accent, func() -> void: continue_pressed.emit(), 26))
	UiKit.pop_in(self)
	stamp.pivot_offset = Vector2(340, 55)
	stamp.scale = Vector2(2.4, 2.4)
	stamp.modulate.a = 0.0
	var tw: Tween = stamp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.32).set_delay(0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.12).set_delay(0.45)
	tw.tween_property(stamp, "rotation", deg_to_rad(-4.0), 0.32).set_delay(0.45)
	tw.chain().tween_callback(func() -> void: EventBus.screen_shake_requested.emit(10.0 if passed else 18.0, 0.3))


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and is_visible_in_tree() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		continue_pressed.emit()
