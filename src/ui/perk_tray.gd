class_name PerkTray
extends HBoxContainer
## Bottom tray of equipped Contact/Perk JuicyCards plus empty-slot placeholders.

const CARD_SIZE: Vector2 = Vector2(180, 226)

var cards: Dictionary = {} # source_id -> JuicyCard


func show_perks(perks: Array[PerkDef], slots: int, disabled_ids: Array[String] = []) -> void:
	for c: Node in get_children():
		c.queue_free()
	cards.clear()
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var idx: int = 0
	for p: PerkDef in perks:
		var card: JuicyCard = JuicyCard.new()
		card.slot_index = idx
		card.setup(p.id, p.name, "%s · %s" % [p.rarity, _phase_tag(p.phase)], p.description, "", Color(p.accent_color), p.foil_tier, CARD_SIZE)
		card.set_footer("SELL %s" % ThemeTokens.format_currency(float(p.cost) * 0.5), ThemeTokens.TEXT_MUTED)
		card.interactive = false
		add_child(card)
		if disabled_ids.has(p.id):
			card.set_dimmed(true)
			card.set_footer("FROZEN BY BOSS", ThemeTokens.MARGIN_CRIMSON)
		cards[p.id] = card
		idx += 1
	for i: int in range(perks.size(), slots):
		var empty: PanelContainer = PanelContainer.new()
		var sb: StyleBoxFlat = ThemeTokens.create_glass_panel_stylebox(0.25, Color(ThemeTokens.BORDER_HAIRLINE, 0.9), 14)
		empty.add_theme_stylebox_override("panel", sb)
		empty.custom_minimum_size = CARD_SIZE
		var l: Label = ThemeTokens.make_label("EMPTY\nCONTACT\nSLOT", 18, Color(ThemeTokens.TEXT_MUTED, 0.6), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		add_child(empty)


func _phase_tag(phase: String) -> String:
	match phase:
		"FLAT_ALPHA":
			return "+$"
		"ADDITIVE_MULT":
			return "+x"
		"COMPOUND_XMULT":
			return "x"
		"BASE_ALPHA":
			return "BASE"
	return "PASSIVE"


## Pops the card that produced a trigger step (no-op for base-game sources).
func pop(source_id: String, label: String, color: Color, shake: float) -> Vector2:
	if cards.has(source_id):
		var c: JuicyCard = cards[source_id]
		c.play_trigger_pop(label, color, shake)
		return c.global_position + Vector2(c.size.x * 0.5, 0.0)
	return Vector2(-1, -1)
