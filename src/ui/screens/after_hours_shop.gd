class_name AfterHoursShop
extends Control
## After-Hours shop (Stage 4A): Tab 1 "Contacts & Algos" is live (buy / sell / lock / reroll);
## Lifestyle and Shady Deals tabs are shown as COMING SOON; the Algo Rack is OFFLINE.

signal next_session_pressed

const TIER_NAMES: Array[String] = ["RETAIL", "HEDGE FUND", "WHALE"]

var run: RunController
var _stats: HBoxContainer
var _offers_row: HBoxContainer
var _owned_row: HBoxContainer
var _reroll_btn: Button
var _next_btn: Button
var _status: Label


func build(r: RunController) -> void:
	run = r
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	add_child(m)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	m.add_child(root)
	root.add_child(_glass(_build_header()))
	root.add_child(_build_tabs())
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var wire: VBoxContainer = VBoxContainer.new()
	wire.add_theme_constant_override("separation", 10)
	wire.add_child(ThemeTokens.make_label("ON THE WIRE TONIGHT", 22, ThemeTokens.LUXURY_GOLD, true))
	_offers_row = HBoxContainer.new()
	_offers_row.add_theme_constant_override("separation", 26)
	_offers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wire.add_child(_offers_row)
	var wp: PanelContainer = _glass(wire)
	wp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(wp)
	body.add_child(_glass(_build_side(), Vector2(430, 0)))
	var owned: VBoxContainer = VBoxContainer.new()
	owned.add_theme_constant_override("separation", 8)
	owned.add_child(ThemeTokens.make_label("YOUR CONTACTS  ·  click a card to SELL for 50%", 20, ThemeTokens.TEXT_MUTED, true))
	_owned_row = HBoxContainer.new()
	_owned_row.add_theme_constant_override("separation", 14)
	owned.add_child(_owned_row)
	root.add_child(_glass(owned, Vector2(0, 300)))
	run.shop_changed.connect(refresh)


func _build_header() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	var t: VBoxContainer = VBoxContainer.new()
	t.add_child(ThemeTokens.make_label("AFTER-HOURS", 56, ThemeTokens.LUXURY_GOLD, true, true))
	t.add_child(ThemeTokens.make_label("The market is closed. Your Contacts are not.", 18, ThemeTokens.TEXT_MUTED))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 34)
	row.add_child(_stats)
	return row


func _build_tabs() -> HBoxContainer:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	for spec: Array in [["CONTACTS & ALGOS", true], ["LIFESTYLE · COMING SOON", false], ["SHADY DEALS · COMING SOON", false]]:
		var b: Button = UiKit.button(str(spec[0]), ThemeTokens.LUXURY_GOLD if bool(spec[1]) else ThemeTokens.BORDER_HAIRLINE, func() -> void: pass, 20, bool(spec[1]))
		b.disabled = not bool(spec[1])
		b.custom_minimum_size = Vector2(380, 50)
		tabs.add_child(b)
	return tabs


func _build_side() -> VBoxContainer:
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.add_child(ThemeTokens.make_label("ALGO RACK", 22, ThemeTokens.ALGO_CYAN, true))
	var off: PanelContainer = PanelContainer.new()
	off.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox(0.5, Color(ThemeTokens.ALGO_CYAN, 0.5), 10))
	var ol: Label = ThemeTokens.make_label("▣ ▣ ▣ ▣   OFFLINE\nTrading bots arrive in the\nnext build (Stage 5).", 18, Color(ThemeTokens.ALGO_CYAN, 0.75), true)
	ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	off.add_child(ol)
	side.add_child(off)
	_status = ThemeTokens.make_label("", 18, ThemeTokens.TEXT_IVORY, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_status)
	_reroll_btn = UiKit.button("REROLL", ThemeTokens.AMBER, _on_reroll, 22, false)
	side.add_child(_reroll_btn)
	_next_btn = UiKit.button("NEXT SESSION  ▸  [ENTER]", ThemeTokens.PROFIT_EMERALD, func() -> void: next_session_pressed.emit(), 24)
	_next_btn.custom_minimum_size = Vector2(0, 72)
	side.add_child(_next_btn)
	return side


func refresh() -> void:
	if run == null or run.phase != "AFTER_HOURS":
		return
	var info: Dictionary = run.get_hud_info()
	var cash: float = run.session.portfolio.cash
	for c: Node in _stats.get_children():
		c.queue_free()
	_stat("QUARTER", "Q%d" % run.quarter, ThemeTokens.TEXT_IVORY)
	_stat("CASH", ThemeTokens.format_currency(cash), ThemeTokens.PROFIT_EMERALD)
	_stat("TARGET", ThemeTokens.format_currency(float(info["target"])), ThemeTokens.LUXURY_GOLD)
	_stat("BURN", ThemeTokens.format_currency(float(info["burn_rate"])), ThemeTokens.MARGIN_CRIMSON)
	_stat("PRESTIGE", "%d · %s" % [int(run.life.prestige), TIER_NAMES[clampi(run.life.shop_tier(), 0, 2)]], ThemeTokens.ALGO_CYAN)
	var owned: Array[PerkDef] = run.session.loadout.perk_defs()
	for c: Node in _offers_row.get_children():
		c.queue_free()
	for i: int in run.shop.offers.size():
		var o: Dictionary = run.shop.offers[i]
		var d: PerkDef = run.data.get_perk(str(o["id"]))
		if d == null:
			continue
		var slot: ShopOfferSlot = ShopOfferSlot.new()
		slot.build(i, o, d, ShopOfferSlot.synergy_for(d, owned), cash >= float(o["cost"]))
		slot.buy_requested.connect(_on_buy)
		slot.lock_requested.connect(func(k: int) -> void: run.toggle_lock(k))
		_offers_row.add_child(slot)
	_refresh_owned(owned)
	var rc: int = run.shop.reroll_cost(run.quarter)
	_reroll_btn.text = "REROLL  %s  [R]" % ThemeTokens.format_currency(float(rc))
	_reroll_btn.disabled = cash < float(rc)
	var next_idx: int = run.session_idx + 1
	var boss: Dictionary = run.current_boss()
	if next_idx > RunController.SESSIONS_PER_QUARTER:
		_status.text = "NEXT: QUARTERLY BOSS\n%s\n%s\n\nAudit: net equity after burn + tax must be ≥ %s." % [str(boss["name"]).to_upper(), str(boss["description"]), ThemeTokens.format_currency(float(info["target"]))]
		_status.add_theme_color_override("font_color", ThemeTokens.MARGIN_CRIMSON)
	else:
		_status.text = "NEXT: SESSION %d of %d\nBoss this quarter: %s\n\nQuarter gains so far: %s" % [next_idx, RunController.SESSIONS_PER_QUARTER, str(boss["name"]), ThemeTokens.format_currency(run.quarter_gains, 0, true)]
		_status.add_theme_color_override("font_color", ThemeTokens.TEXT_IVORY)


func _refresh_owned(owned: Array[PerkDef]) -> void:
	for c: Node in _owned_row.get_children():
		c.queue_free()
	var i: int = 0
	for d: PerkDef in owned:
		var card: JuicyCard = JuicyCard.new()
		card.slot_index = i
		card.setup(d.id, d.name, d.rarity, d.description, "", Color(d.accent_color), d.foil_tier, Vector2(190, 236))
		var inst: PerkInstance = run.session.loadout.get_perk(d.id)
		var paid: int = inst.paid if inst != null and inst.paid > 0 else d.cost
		card.set_footer("SELL +%s" % ThemeTokens.format_compact(float(run.shop.sellback(paid))), ThemeTokens.AMBER)
		var pid: String = d.id
		card.card_pressed.connect(func(_c: JuicyCard) -> void: _on_sell(pid))
		_owned_row.add_child(card)
		i += 1
	for k: int in range(owned.size(), run.session.loadout.perk_slots):
		var e: Label = ThemeTokens.make_label("EMPTY\nSLOT", 18, Color(ThemeTokens.TEXT_MUTED, 0.5), true)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.custom_minimum_size = Vector2(190, 236)
		_owned_row.add_child(e)


func _stat(title: String, value: String, col: Color) -> void:
	var b: VBoxContainer = VBoxContainer.new()
	b.add_child(ThemeTokens.make_label(title, 16, ThemeTokens.TEXT_MUTED, true))
	b.add_child(ThemeTokens.make_label(value, 30, col, true))
	_stats.add_child(b)


func _on_buy(i: int) -> void:
	var res: Dictionary = run.buy_shop_item(i)
	if not bool(res.get("ok", false)):
		FloatingPopup.spawn_global(str(res.get("reason", "No")), ThemeTokens.MARGIN_CRIMSON, get_global_mouse_position(), 26, 50.0)
	else:
		EventBus.screen_shake_requested.emit(5.0, 0.12)


func _on_sell(pid: String) -> void:
	var res: Dictionary = run.sell_perk(pid)
	if bool(res.get("ok", false)):
		FloatingPopup.spawn_global("+%s" % ThemeTokens.format_currency(float(res["refund"])), ThemeTokens.AMBER, get_global_mouse_position(), 30, 60.0)


func _on_reroll() -> void:
	var res: Dictionary = run.reroll_shop()
	if not bool(res.get("ok", false)):
		FloatingPopup.spawn_global(str(res.get("reason", "No")), ThemeTokens.MARGIN_CRIMSON, _reroll_btn.global_position, 24, 40.0)


func _glass(child: Control, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeTokens.create_glass_panel_stylebox())
	p.custom_minimum_size = min_size
	p.add_child(child)
	return p


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	if k.keycode == KEY_R:
		_on_reroll()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		next_session_pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
