class_name PerkDef
extends RefCounted
## Typed Contact/Perk definition (data/contacts_perks.json).

const REQUIRED_KEYS: Array[String] = [
	"id", "name", "rarity", "archetype", "cost", "min_prestige", "description",
	"trigger_hook", "phase", "condition", "effect", "accent_color", "foil_tier",
]
const VALID_PHASES: Array[String] = ["BASE_ALPHA", "FLAT_ALPHA", "ADDITIVE_MULT", "COMPOUND_XMULT", "PASSIVE"]
const VALID_HOOKS: Array[String] = ["ON_TRADE_CLOSE", "ON_SESSION_END", "ON_WALL_SMASH", "PASSIVE"]
const VALID_RARITIES: Array[String] = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY"]

var id: String = ""
var name: String = ""
var rarity: String = "COMMON"
var archetype: String = ""
var cost: int = 0
var min_prestige: int = 0
var description: String = ""
var trigger_hook: String = "ON_TRADE_CLOSE"
var phase: String = "FLAT_ALPHA"
var condition: Dictionary = {}
var effect: Dictionary = {}
var passive_mods: Array[Dictionary] = []
var accent_color: String = "#D4AF37"
var foil_tier: int = 1
var shop_eligible: bool = true
var requires_feature: String = ""
var tags: Array[String] = []


static func from_dict(d: Dictionary) -> PerkDef:
	var p: PerkDef = PerkDef.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.rarity = str(d.get("rarity", "COMMON"))
	p.archetype = str(d.get("archetype", ""))
	p.cost = int(d.get("cost", 0))
	p.min_prestige = int(d.get("min_prestige", 0))
	p.description = str(d.get("description", ""))
	p.trigger_hook = str(d.get("trigger_hook", "ON_TRADE_CLOSE"))
	p.phase = str(d.get("phase", "FLAT_ALPHA"))
	p.condition = d.get("condition", {})
	p.effect = d.get("effect", {})
	p.accent_color = str(d.get("accent_color", "#D4AF37"))
	p.foil_tier = int(d.get("foil_tier", 1))
	p.shop_eligible = bool(d.get("shop_eligible", true))
	p.requires_feature = str(d.get("requires_feature", ""))
	var mods: Array = d.get("passive_mods", [])
	for m: Variant in mods:
		if m is Dictionary:
			p.passive_mods.append(m as Dictionary)
	var tg: Array = d.get("tags", [])
	for t: Variant in tg:
		p.tags.append(str(t))
	return p
