class_name AlgoDef
extends RefCounted
## Typed Active Algo definition (data/algos_strategies.json). Live effects arrive in Stage 5.

const REQUIRED_KEYS: Array[String] = ["id", "name", "rarity", "cost", "description", "effect", "accent_color", "foil_tier"]

var id: String = ""
var name: String = ""
var rarity: String = "COMMON"
var cost: int = 0
var min_prestige: int = 0
var description: String = ""
var effect: Dictionary = {}
var accent_color: String = "#38BDF8"
var foil_tier: int = 1
var tags: Array[String] = []


static func from_dict(d: Dictionary) -> AlgoDef:
	var a: AlgoDef = AlgoDef.new()
	a.id = str(d.get("id", ""))
	a.name = str(d.get("name", ""))
	a.rarity = str(d.get("rarity", "COMMON"))
	a.cost = int(d.get("cost", 0))
	a.min_prestige = int(d.get("min_prestige", 0))
	a.description = str(d.get("description", ""))
	a.effect = d.get("effect", {})
	a.accent_color = str(d.get("accent_color", "#38BDF8"))
	a.foil_tier = int(d.get("foil_tier", 1))
	var tg: Array = d.get("tags", [])
	for t: Variant in tg:
		a.tags.append(str(t))
	return a
