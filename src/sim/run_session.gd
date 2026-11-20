class_name RunSession
extends SessionRunner
## SessionRunner + owned Loadout: applies passive perk mods each session and resolves every
## trade close / session settlement through the ordered 4-phase ModifierPipeline.

signal perk_scaled(perk_id: String, new_value: float)
signal stop_loss_fired(pos_id: String)

var loadout: Loadout = Loadout.new()
var pipeline: ModifierPipeline = ModifierPipeline.new()
var life_stats: Dictionary = {"stress": 0.0, "sec_heat_stars": 0.0, "prestige": 0.0}
var base_mults: Dictionary = {}


func _init(cfg: Dictionary, stocks: Array[StockDef], rng: RNGService, starting_cash: float) -> void:
	super(cfg, stocks, rng, starting_cash)
	base_mults = cfg.get("base_mults", {})


## Call before begin(): pushes passive mods into the market/portfolio/momentum engines.
func apply_loadout() -> void:
	portfolio.spread_mult = loadout.mult("spread_mult")
	momentum.short_gain_mult = loadout.mult("momentum_gain_short")
	momentum.wall_bonus_mult = loadout.mult("wall_bonus_mult")
	market.fed_whisperer = loadout.has_mod("fed_whisperer")
	portfolio.sector_borrow_mult.clear()
	for m: Dictionary in loadout.mods("borrow_mult"):
		for sec: Variant in m.get("sectors", []):
			var cur: float = float(portfolio.sector_borrow_mult.get(str(sec), 1.0))
			portfolio.sector_borrow_mult[str(sec)] = cur * float(m["value"])


func trade_context(p: PositionState, raw_pnl: float) -> Dictionary:
	var ctx: Dictionary = life_stats.duplicate()
	ctx["trade_pnl"] = raw_pnl + p.wall_bonus
	ctx["side"] = p.side
	ctx["leverage"] = p.leverage
	ctx["entry_regime"] = p.entry_regime
	ctx["trade_ticks_in_profit"] = p.ticks_in_profit
	ctx["walls_this_trade"] = p.walls_smashed
	ctx["session_profit"] = session_realized
	ctx["session_floors"] = momentum.session_floors_broken
	ctx["session_walls"] = momentum.session_walls_broken
	ctx["min_margin"] = min_margin
	ctx["momentum"] = momentum.momentum
	ctx["distinct_algos"] = loadout.distinct_algos()
	ctx["session_crash_red_candles"] = crash_red_candles
	return ctx


func resolve_trade(p: PositionState, raw_pnl: float) -> Dictionary:
	var base_items: Array[Dictionary] = [{"source_id": "BASE_PNL", "label": "Realized P&L", "value": raw_pnl}]
	if p.wall_bonus > 0.0:
		base_items.append({"source_id": "BASE_WALLS", "label": "Wall Smash Bonus", "value": p.wall_bonus})
	var game: Array[Dictionary] = []
	var k_mult: float = float(base_mults.get("momentum_add_mult_at_full", 0.0)) * momentum.momentum / 100.0
	if k_mult >= 0.01:
		game.append({"source_id": "GAME_MOMENTUM", "label": "Kinetic Momentum", "phase": "ADDITIVE_MULT", "value": snappedf(k_mult, 0.01)})
	if p.walls_smashed > 0:
		var w_mult: float = float(base_mults.get("wall_add_mult_per_smash", 0.0)) * float(p.walls_smashed)
		game.append({"source_id": "GAME_WALLS", "label": "Walls Smashed x%d" % p.walls_smashed, "phase": "ADDITIVE_MULT", "value": w_mult})
	return pipeline.evaluate("ON_TRADE_CLOSE", trade_context(p, raw_pnl), loadout.active_perks(), base_items, game)


func resolve_session() -> Dictionary:
	var ctx: Dictionary = life_stats.duplicate()
	ctx["session_profit"] = session_realized
	ctx["min_margin"] = min_margin
	ctx["session_floors"] = momentum.session_floors_broken
	ctx["session_crash_red_candles"] = crash_red_candles
	ctx["survived"] = not was_margin_called
	var base_items: Array[Dictionary] = [{"source_id": "BASE_SESSION", "label": "Session P&L", "value": session_realized}]
	var res: Dictionary = pipeline.evaluate("ON_SESSION_END", ctx, loadout.active_perks(), base_items)
	var steps: Array = res["steps"]
	if steps.size() <= 1 or was_margin_called:
		return {"bonus": 0.0, "steps": []}
	return {"bonus": float(res["payout"]) - session_realized, "steps": steps}


func _on_wall_event(e: Dictionary) -> void:
	var ctx: Dictionary = life_stats.duplicate()
	ctx["side"] = str(e["side"])
	for inst: PerkInstance in pipeline.notify("ON_WALL_SMASH", ctx, loadout.active_perks()):
		perk_scaled.emit(inst.def.id, inst.counter)


## Stop-Loss Guardian: closes the worst position before Margin falls under its threshold.
func _pre_margin_check(m: float) -> bool:
	var mods: Array[Dictionary] = loadout.mods("stop_loss_threshold")
	if mods.is_empty() or portfolio.positions.is_empty():
		return false
	var threshold: float = float(mods[0]["value"])
	if m >= threshold:
		return false
	for inst: PerkInstance in loadout.active_perks():
		if inst.charges > 0 and inst.def.passive_mods.any(func(d: Dictionary) -> bool: return str(d.get("key", "")) == "stop_loss_threshold"):
			var worst: PositionState = portfolio.positions[0]
			for p: PositionState in portfolio.positions:
				if p.unrealized_pnl < worst.unrealized_pnl:
					worst = p
			inst.charges -= 1
			stop_loss_fired.emit(worst.id)
			close_position(worst.id)
			return true
	return false
