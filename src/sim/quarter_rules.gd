class_name QuarterRules
extends RefCounted
## Quarter economy + Boss modifier application (Part 2.2 / 2.6). Pure functions over the session.

var config: Dictionary
var econ: Dictionary
var bosses: Array[Dictionary] = []


func _init(cfg: Dictionary, boss_list: Array[Dictionary]) -> void:
	config = cfg
	econ = cfg.get("economy", {})
	bosses = boss_list


func boss_for(quarter: int) -> Dictionary:
	for b: Dictionary in bosses:
		if int(b["quarter"]) == quarter:
			return b
	return bosses[bosses.size() - 1] if not bosses.is_empty() else {}


## Expands RANDOM_BOSS_MODIFIERS (The Sovereign Reckoning) into concrete modifiers.
func resolve_modifiers(boss: Dictionary, rng: RNGService) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Variant in boss.get("modifiers", []):
		var md: Dictionary = m
		if str(md["key"]) != "RANDOM_BOSS_MODIFIERS":
			out.append(md)
			continue
		var pool: Array[Dictionary] = []
		for b: Dictionary in bosses:
			if int(b["quarter"]) < int(boss["quarter"]):
				pool.append(b)
		for i: int in mini(int(md["value"]), pool.size()):
			var pick: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			for pm: Variant in pick["modifiers"]:
				out.append(pm as Dictionary)
	return out


## Applies boss modifiers to a session. Returns a summary of effects for the HUD/banner.
func apply_boss(s: RunSession, mods: Array[Dictionary], rng: RNGService) -> Dictionary:
	var fx: Dictionary = {"tax_rate_add": 0.0, "sec_stars_add": 0.0}
	var forced: Array[Dictionary] = []
	for m: Dictionary in mods:
		match str(m["key"]):
			"SPREAD_MULT":
				s.market.spread_mult *= float(m["value"])
			"FORCED_JUMP":
				forced.append({"tick": int(m["tick"]), "ticker": str(m["ticker"]), "size_std": float(m["size_std"])})
			"DISABLE_SHORTS":
				s.portfolio.shorts_enabled = false
			"TAX_RATE_ADD":
				fx["tax_rate_add"] = float(fx["tax_rate_add"]) + float(m["value"])
			"REGIME_DRIFT_ADD":
				s.market.drift_add += float(m["value"])
			"VOL_MULT":
				s.market.vol_mult *= float(m["value"])
			"DISABLE_LEFTMOST_PERK":
				if not s.loadout.perks.is_empty():
					s.loadout.disabled_perk_ids.append(s.loadout.perks[0].def.id)
			"CIRCUIT_BREAKER":
				s.market.circuit_threshold = float(m["threshold"])
				s.market.circuit_halt_ticks = int(m["halt_ticks"])
			"LIQUIDATION_THRESHOLD":
				s.portfolio.margin_liquidation = float(m["value"])
			"MAX_LEVERAGE":
				s.portfolio.max_leverage_cap = int(m["value"])
			"BORROW_MULT":
				s.portfolio.borrow_mult *= float(m["value"])
			"FLASH_CRASH":
				forced.append({"tick": rng.randi_range(120, 400), "ticker": "ALL", "log_size": log(1.0 + float(m["value"]))})
			"SEC_STARS_ADD":
				fx["sec_stars_add"] = float(fx["sec_stars_add"]) + float(m["value"]) # Stage 4B consumes this
	s.market.jumps.set_forced(forced)
	return fx


## Restores every engine knob a boss may have touched.
func clear_boss(s: RunSession) -> void:
	s.market.spread_mult = 1.0
	s.market.vol_mult = 1.0
	s.market.drift_add = 0.0
	s.market.circuit_threshold = 0.0
	s.market.circuit_halt_ticks = 0
	s.market.jumps.set_forced([] as Array[Dictionary])
	s.portfolio.shorts_enabled = true
	s.portfolio.margin_liquidation = float(config["margin_liquidation"])
	s.portfolio.max_leverage_cap = 10
	s.portfolio.borrow_mult = 1.0
	s.loadout.disabled_perk_ids.clear()


## Capital gains tax on positive realized quarter gains.
func tax_rate(tax_rate_add: float) -> float:
	return clampf(float(econ.get("capital_gains_tax_rate", 0.15)) + tax_rate_add, 0.0, 1.0)


func capital_gains_tax(quarter_gains: float, tax_rate_add: float) -> float:
	return maxf(quarter_gains, 0.0) * tax_rate(tax_rate_add)


## Audit: pay Burn Rate + Tax, then net equity must clear the Target (else Insolvency).
func audit(equity: float, target: float, burn: float, tax: float) -> Dictionary:
	var due: float = burn + tax
	var net: float = equity - due
	var passed: bool = equity >= due and net >= target
	var reason: String = "CLEARED"
	if equity < due:
		reason = "CANNOT COVER BURN + TAX"
	elif net < target:
		reason = "BELOW TARGET EQUITY"
	return {"equity_before": equity, "burn": burn, "tax": tax, "due": due, "net": net, "target": target, "passed": passed, "reason": reason}
