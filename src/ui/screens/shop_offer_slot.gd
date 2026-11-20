class_name ShopOfferSlot
extends VBoxContainer
## One After-Hours offer: JuicyCard + synergy line + BUY / LOCK buttons.

signal buy_requested(idx: int)
signal lock_requested(idx: int)

const CARD_SIZE: Vector2 = Vector2(250, 318)

var idx: int = 0
var card: JuicyCard


func build(i: int, offer: Dictionary, def: PerkDef, synergy: String, can_afford: bool) -> void:
	idx = i
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	var sold: bool = bool(offer["sold"])
	var locked: bool = bool(offer["locked"])
	card = JuicyCard.new()
	card.slot_index = i
	var tag: String = "%s · %s" % [def.rarity, def.archetype.replace("_", " ")]
	card.setup(def.id, def.name, tag, def.description, "", Color(def.accent_color), def.foil_tier, CARD_SIZE)
	card.set_footer(ThemeTokens.format_currency(float(offer["cost"])), ThemeTokens.LUXURY_GOLD if can_afford else ThemeTokens.MARGIN_CRIMSON)
	card.card_pressed.connect(func(_c: JuicyCard) -> void: buy_requested.emit(idx))
	if sold:
		card.set_dimmed(true)
		card.set_footer("SIGNED", ThemeTokens.PROFIT_EMERALD)
		card.interactive = false
	add_child(card)
	var syn: Label = ThemeTokens.make_label(synergy if synergy != "" else " ", 16, ThemeTokens.ALGO_CYAN, true)
	syn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	syn.custom_minimum_size = Vector2(CARD_SIZE.x, 22)
	syn.clip_text = true
	add_child(syn)
	var buy: Button = UiKit.button("SOLD" if sold else "BUY  %s" % ThemeTokens.format_compact(float(offer["cost"])), ThemeTokens.PROFIT_EMERALD, func() -> void: buy_requested.emit(idx), 20)
	buy.disabled = sold or not can_afford
	buy.custom_minimum_size = Vector2(CARD_SIZE.x, 48)
	add_child(buy)
	var lock: Button = UiKit.button("LOCKED ■" if locked else "LOCK", ThemeTokens.AMBER, func() -> void: lock_requested.emit(idx), 18, locked)
	lock.disabled = sold
	lock.custom_minimum_size = Vector2(CARD_SIZE.x, 40)
	add_child(lock)


static func synergy_for(def: PerkDef, owned: Array[PerkDef]) -> String:
	var hits: int = 0
	var tag: String = ""
	for o: PerkDef in owned:
		if o.id == def.id:
			continue
		var shared: String = def.archetype.get_slice("_", 0) if o.archetype == def.archetype else ""
		for t: String in def.tags:
			if o.tags.has(t):
				shared = t
		if shared != "":
			hits += 1
			tag = shared
	if hits == 0:
		return "#" + " #".join(def.tags)
	return "SYNERGY ×%d · #%s" % [hits, tag]
