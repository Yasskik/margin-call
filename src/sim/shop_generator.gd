class_name ShopGenerator
extends RefCounted
## Brotato-style After-Hours shop: rarity odds by Prestige tier, escalating reroll cost,
## offer locking between visits and 50% sellback math. Pure logic on an injected RNGService.

var econ: Dictionary
var rng: RNGService
var perks: Array[PerkDef] = []
var algos: Array[AlgoDef] = []
var features: Dictionary = {}
var offers: Array[Dictionary] = [] # {kind, id, rarity, base_cost, cost, locked, sold}
var rerolls_this_visit: int = 0


func _init(economy: Dictionary, perk_pool: Array[PerkDef], algo_pool: Array[AlgoDef], feature_flags: Dictionary, rng_service: RNGService) -> void:
	econ = economy
	perks = perk_pool
	algos = algo_pool
	features = feature_flags
	rng = rng_service


func offer_count() -> int:
	return int(econ.get("shop_offer_count", 4))


func item_cost(base_cost: int, quarter: int) -> int:
	return int(round(float(base_cost) * (1.0 + float(econ.get("item_cost_quarter_scale", 0.0)) * float(quarter - 1))))


## cost(n, q) = base * (1 + qs * (q - 1)) + step * n   (n = rerolls already bought this visit)
func reroll_cost(quarter: int) -> int:
	var base: float = float(econ["reroll_base_cost"]) * (1.0 + float(econ.get("reroll_quarter_scale", 0.0)) * float(quarter - 1))
	return int(round(base + float(econ["reroll_step_cost"]) * float(rerolls_this_visit)))


func sellback(paid: int) -> int:
	return int(floor(float(paid) * float(econ.get("sellback_ratio", 0.5))))


## New visit: keeps locked unsold offers, refills the rest, resets the reroll curve.
func open_visit(quarter: int, prestige: float, tier: int, owned: Array[String]) -> void:
	rerolls_this_visit = 0
	_refill(quarter, prestige, tier, owned)


func reroll(quarter: int, prestige: float, tier: int, owned: Array[String]) -> void:
	rerolls_this_visit += 1
	_refill(quarter, prestige, tier, owned)


func toggle_lock(idx: int) -> bool:
	if idx < 0 or idx >= offers.size() or bool(offers[idx]["sold"]):
		return false
	offers[idx]["locked"] = not bool(offers[idx]["locked"])
	return bool(offers[idx]["locked"])


func _refill(quarter: int, prestige: float, tier: int, owned: Array[String]) -> void:
	var kept: Array[Dictionary] = []
	for o: Dictionary in offers:
		if bool(o["locked"]) and not bool(o["sold"]):
			kept.append(o)
	var next: Array[Dictionary] = []
	var exclude: Array[String] = owned.duplicate()
	for o: Dictionary in kept:
		exclude.append(str(o["id"]))
	var k: int = 0
	for i: int in offer_count():
		if k < kept.size():
			var o: Dictionary = kept[k]
			o["cost"] = item_cost(int(o["base_cost"]), quarter)
			next.append(o)
			k += 1
			continue
		var roll: Dictionary = roll_offer(quarter, prestige, tier, exclude)
		if roll.is_empty():
			break
		exclude.append(str(roll["id"]))
		next.append(roll)
	offers = next


func eligible(prestige: float, exclude: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: PerkDef in perks:
		var req: String = p.requires_feature
		if p.shop_eligible and float(p.min_prestige) <= prestige and not exclude.has(p.id) and (req == "" or bool(features.get(req, false))):
			out.append({"kind": "PERK", "id": p.id, "rarity": p.rarity, "base_cost": p.cost})
	if bool(features.get("algos_live", false)):
		for a: AlgoDef in algos:
			if float(a.min_prestige) <= prestige and not exclude.has(a.id):
				out.append({"kind": "ALGO", "id": a.id, "rarity": a.rarity, "base_cost": a.cost})
	return out


func roll_offer(quarter: int, prestige: float, tier: int, exclude: Array[String]) -> Dictionary:
	var pool: Array[Dictionary] = eligible(prestige, exclude)
	if pool.is_empty():
		return {}
	var odds_list: Array = econ["rarity_odds_by_tier"]
	var odds: Dictionary = odds_list[clampi(tier, 0, odds_list.size() - 1)]
	var present: Dictionary = {}
	for c: Dictionary in pool:
		present[str(c["rarity"])] = float(odds.get(str(c["rarity"]), 0.0))
	var rarity: String = rng.weighted_pick(present)
	var bucket: Array[Dictionary] = pool.filter(func(c: Dictionary) -> bool: return str(c["rarity"]) == rarity)
	if bucket.is_empty():
		bucket = pool
	var pick: Dictionary = bucket[rng.randi_range(0, bucket.size() - 1)].duplicate()
	pick["cost"] = item_cost(int(pick["base_cost"]), quarter)
	pick["locked"] = false
	pick["sold"] = false
	return pick

