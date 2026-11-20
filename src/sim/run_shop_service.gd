class_name RunShopService
extends RefCounted
## After-Hours shop commands executed against a RunController (buy / sell / reroll).


static func owned_ids(r: RunController) -> Array[String]:
	var ids: Array[String] = []
	for p: PerkInstance in r.session.loadout.perks:
		ids.append(p.def.id)
	for a: AlgoDef in r.session.loadout.algos:
		ids.append(a.id)
	return ids


static func buy(r: RunController, idx: int) -> Dictionary:
	if r.phase != "AFTER_HOURS" or idx < 0 or idx >= r.shop.offers.size():
		return {"ok": false, "reason": "Shop closed"}
	var o: Dictionary = r.shop.offers[idx]
	var cost: int = int(o["cost"])
	if bool(o["sold"]):
		return {"ok": false, "reason": "Sold out"}
	if r.session.portfolio.cash < float(cost):
		return {"ok": false, "reason": "Not enough cash"}
	var ok: bool = false
	if str(o["kind"]) == "PERK":
		ok = r.session.loadout.add_perk(r.data.get_perk(str(o["id"])))
		if ok:
			r.session.loadout.get_perk(str(o["id"])).paid = cost
	else:
		ok = r.session.loadout.add_algo(r.data.get_algo(str(o["id"])))
	if not ok:
		return {"ok": false, "reason": "No free slot"}
	r.session.portfolio.cash -= float(cost)
	o["sold"] = true
	o["locked"] = false
	r.shop_changed.emit()
	return {"ok": true, "reason": "Bought", "cost": cost}


static func sell(r: RunController, perk_id: String) -> Dictionary:
	if r.phase != "AFTER_HOURS":
		return {"ok": false, "reason": "Shop closed"}
	var inst: PerkInstance = r.session.loadout.get_perk(perk_id)
	if inst == null:
		return {"ok": false, "reason": "Not owned"}
	var paid: int = inst.paid if inst.paid > 0 else inst.def.cost
	var refund: int = r.shop.sellback(paid)
	r.session.loadout.remove_perk(perk_id)
	r.session.portfolio.cash += float(refund)
	r.shop_changed.emit()
	return {"ok": true, "refund": refund}


static func reroll(r: RunController) -> Dictionary:
	if r.phase != "AFTER_HOURS":
		return {"ok": false, "reason": "Shop closed"}
	var cost: int = r.shop.reroll_cost(r.quarter)
	if r.session.portfolio.cash < float(cost):
		return {"ok": false, "reason": "Not enough cash"}
	r.session.portfolio.cash -= float(cost)
	r.shop.reroll(r.quarter, r.life.prestige, r.life.shop_tier(), owned_ids(r))
	r.shop_changed.emit()
	return {"ok": true, "cost": cost}
