class_name LifeSimState
extends RefCounted
## Stage 4A (minimal): Burn Rate, Prestige with shop-tier lookup, and owned Lifestyle Upgrades.
## Stress / Sleep / SEC Heat are typed placeholders returning 0 so Stage 4B extends this class.

var prestige: float = 0.0
var burn_rate_mult: float = 1.0
var owned_upgrades: Array[String] = []
var prestige_tiers: Array[int] = [0, 25, 60]
var _upgrade_defs: Dictionary = {} # id -> Dictionary


func _init(economy: Dictionary, upgrades: Array[Dictionary]) -> void:
	prestige_tiers.clear()
	for t: Variant in economy.get("prestige_tiers", [0, 25, 60]):
		prestige_tiers.append(int(t))
	for u: Dictionary in upgrades:
		_upgrade_defs[str(u["id"])] = u
		if int(u.get("tier", 0)) == 0:
			owned_upgrades.append(str(u["id"]))


## 0 = Retail, 1 = Hedge Fund, 2 = Wall Street Titans.
func shop_tier() -> int:
	var tier: int = 0
	for i: int in prestige_tiers.size():
		if prestige >= float(prestige_tiers[i]):
			tier = i
	return tier


func add_prestige(amount: float) -> void:
	prestige = clampf(prestige + amount, 0.0, 100.0)


func own_upgrade(id: String) -> void:
	if _upgrade_defs.has(id) and not owned_upgrades.has(id):
		owned_upgrades.append(id)
		add_prestige(float((_upgrade_defs[id] as Dictionary).get("prestige", 0)))


## Quarterly Burn Rate = boss base burn x background mult + owned lifestyle burn adds.
func burn_rate(base_burn: float) -> float:
	var extra: float = 0.0
	for id: String in owned_upgrades:
		extra += float((_upgrade_defs[id] as Dictionary).get("burn_rate_add", 0.0))
	return base_burn * burn_rate_mult + extra


func lifestyle_slots(key: String) -> int:
	var n: int = 0
	for id: String in owned_upgrades:
		n += int((_upgrade_defs[id] as Dictionary).get(key, 0))
	return n


func stress() -> float:
	return 0.0


func sleep() -> float:
	return 0.0


func sec_stars() -> float:
	return 0.0


func stats_dict() -> Dictionary:
	return {"stress": stress(), "sleep": sleep(), "sec_heat_stars": sec_stars(), "prestige": prestige}
