class_name RunHud
extends RefCounted
## Read-only HUD snapshot assembled from the run (keeps RunController under the line cap).


static func build(r: RunController) -> Dictionary:
	var boss: Dictionary = r.current_boss()
	var s: RunSession = r.session
	var odds: Dictionary = {}
	if r.life.owned_upgrades.has("rig_bloomberg_wall"):
		odds = s.market.next_regime_odds()
	return {
		"quarter": r.quarter, "session_idx": r.session_idx, "sessions_per_quarter": RunController.SESSIONS_PER_QUARTER,
		"is_boss": r.is_boss_session(), "boss_name": str(boss.get("name", "")), "boss_desc": str(boss.get("description", "")),
		"target": float(boss.get("target_equity", 0.0)), "burn_rate": r.life.burn_rate(float(boss.get("burn_rate", 0.0))),
		"est_tax": r.rules.capital_gains_tax(r.quarter_gains, float(r.boss_fx.get("tax_rate_add", 0.0))),
		"quarter_gains": r.quarter_gains, "prestige": r.life.prestige, "shop_tier": r.life.shop_tier(),
		"cash": s.portfolio.cash, "equity": s.portfolio.equity(), "seconds_left": s.market.seconds_left(),
		"regime": s.market.regime, "regime_drift": float(r.data.sim_config["regimes"][s.market.regime]["drift"]),
		"regime_odds": odds, "phase": r.phase, "allow_10x": s.portfolio.allow_10x,
	}
