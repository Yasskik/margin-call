extends RefCounted
## Stage 3: exact 4-phase order of operations, dynamic scaling perks and loss protection.


func _perk(id: String, phase: String, effect: Dictionary, cond: Dictionary = {"type": "ALWAYS"}, hook: String = "ON_TRADE_CLOSE") -> PerkInstance:
	return PerkInstance.create(PerkDef.from_dict({
		"id": id, "name": id, "rarity": "COMMON", "archetype": "TEST", "cost": 1000, "min_prestige": 0,
		"description": "", "trigger_hook": hook, "phase": phase, "condition": cond, "effect": effect,
		"accent_color": "#D4AF37", "foil_tier": 1,
	}))


func _base(v: float) -> Array[Dictionary]:
	return [{"source_id": "BASE_PNL", "label": "Realized P&L", "value": v}] as Array[Dictionary]


func test_exact_four_phase_order(a: TestAssert) -> void:
	var pl: ModifierPipeline = ModifierPipeline.new()
	# deliberately shuffled slot order: phases must still resolve 1 -> 2 -> 3 -> 4
	var perks: Array[PerkInstance] = [
		_perk("x2", "COMPOUND_XMULT", {"op": "XMULT", "amount": 2.0}),
		_perk("add04", "ADDITIVE_MULT", {"op": "ADD_MULT", "amount": 0.4}),
		_perk("flat500", "FLAT_ALPHA", {"op": "FLAT_ALPHA", "amount": 500.0}),
		_perk("x15", "COMPOUND_XMULT", {"op": "XMULT", "amount": 1.5}),
		_perk("add06", "ADDITIVE_MULT", {"op": "ADD_MULT", "amount": 0.6}),
	]
	var r: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0}, perks, _base(1000.0))
	a.near(float(r["payout"]), (1000.0 + 500.0) * (1.0 + 0.4 + 0.6) * 2.0 * 1.5, 1e-9, "(1000 + 500) x (1 + 1.0) x 2.0 x 1.5 = 9000")
	var steps: Array = r["steps"]
	var phases: Array[String] = []
	for s: TriggerStep in steps:
		phases.append(s.phase)
	a.eq(phases, ["BASE_ALPHA", "FLAT_ALPHA", "ADDITIVE_MULT", "ADDITIVE_MULT", "COMPOUND_XMULT", "COMPOUND_XMULT"] as Array[String], "strict phase order")
	a.eq((steps[2] as TriggerStep).source_id, "add04", "left-to-right within a phase")
	a.eq((steps[4] as TriggerStep).source_id, "x2", "left-to-right X-Mult")
	var totals: Array[float] = []
	for s: TriggerStep in steps:
		totals.append(s.running_total)
	a.eq(totals, [1000.0, 1500.0, 2100.0, 3000.0, 6000.0, 9000.0] as Array[float], "running totals for the cash counter")
	a.eq((steps[5] as TriggerStep).pitch_step, 5, "pitch steps increment")
	a.eq((steps[1] as TriggerStep).color_hex, "#38BDF8", "Flat Alpha pops Algo Cyan")
	a.eq((steps[4] as TriggerStep).color_hex, "#FF3B5C", "X-Mult pops Margin Crimson")


func test_additive_mults_sum_not_compound(a: TestAssert) -> void:
	var pl: ModifierPipeline = ModifierPipeline.new()
	var perks: Array[PerkInstance] = [_perk("a", "ADDITIVE_MULT", {"op": "ADD_MULT", "amount": 0.5}), _perk("b", "ADDITIVE_MULT", {"op": "ADD_MULT", "amount": 0.5})]
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {}, perks, _base(100.0))["payout"]), 200.0, 1e-9, "1 + 0.5 + 0.5 = x2.0 (not x2.25)")


func test_tape_reader_scaling(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var pl: ModifierPipeline = ModifierPipeline.new()
	var tape: PerkInstance = PerkInstance.create(l.get_perk("perk_tape_reader"))
	var perks: Array[PerkInstance] = [tape]
	a.eq((pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0}, perks, _base(1000.0))["steps"] as Array).size(), 1, "fresh Tape Reader adds nothing")
	for i: int in 3:
		pl.notify("ON_WALL_SMASH", {}, perks)
	a.near(tape.counter, 0.45, 1e-9, "+0.15x per wall smashed (3 walls)")
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0}, perks, _base(1000.0))["payout"]), 1450.0, 1e-9, "applies accumulated +0.45x")
	pl.notify("ON_WALL_SMASH", {}, perks)
	pl.notify("ON_WALL_SMASH", {}, perks)
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0}, perks, _base(1000.0))["payout"]), 1750.0, 1e-9, "keeps scaling permanently (+0.75x)")
	pl.notify("ON_TRADE_CLOSE", {}, perks)
	a.near(tape.counter, 0.75, 1e-9, "other hooks do not scale it")


func test_shadow_senator_dynamic_xmult(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var pl: ModifierPipeline = ModifierPipeline.new()
	var perks: Array[PerkInstance] = [PerkInstance.create(l.get_perk("perk_shadow_senator"))]
	var r2: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0, "sec_heat_stars": 2.0}, perks, _base(1000.0))
	a.near(float(r2["payout"]), 1000.0 * (1.0 + 0.6 * 2.0), 1e-9, "x(1 + 0.6 * 2 stars) = x2.2")
	var r0: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": 1000.0, "sec_heat_stars": 0.0}, perks, _base(1000.0))
	a.eq((r0["steps"] as Array).size(), 1, "x1.0 at zero stars is a silent no-op")
	var rl: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": -500.0, "sec_heat_stars": 4.0}, perks, _base(-500.0))
	a.near(float(rl["payout"]), -500.0, 1e-9, "losing trade never multiplied")


func test_loss_protection(a: TestAssert) -> void:
	var pl: ModifierPipeline = ModifierPipeline.new()
	var perks: Array[PerkInstance] = [
		_perk("flat300", "FLAT_ALPHA", {"op": "FLAT_ALPHA", "amount": 300.0}),
		_perk("add", "ADDITIVE_MULT", {"op": "ADD_MULT", "amount": 1.0}),
		_perk("x3", "COMPOUND_XMULT", {"op": "XMULT", "amount": 3.0}),
	]
	var r: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": -1000.0}, perks, _base(-1000.0))
	a.near(float(r["payout"]), -700.0, 1e-9, "(-1000 + 300) stays -700: mults never scale losses")
	a.ok(bool(r["loss_protected"]), "loss protection flag")
	for s: TriggerStep in r["steps"]:
		a.ok(s.phase == "BASE_ALPHA" or s.phase == "FLAT_ALPHA", "no mult steps on a loss")
	var r2: Dictionary = pl.evaluate("ON_TRADE_CLOSE", {"trade_pnl": -100.0}, perks, _base(-100.0))
	a.near(float(r2["payout"]), (200.0) * 2.0 * 3.0, 1e-9, "flat alpha that flips a loss positive is multiplied")


func test_real_perk_conditions(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	a.eq(l.perks.size(), 19, "18 launch perks + Bloomberg Trial starter")
	var archetypes: Dictionary = {}
	for p: PerkDef in l.perks:
		archetypes[p.archetype] = int(archetypes.get(p.archetype, 0)) + 1
	a.ok(archetypes.size() >= 4, "perks span the 4 archetypes")
	var pl: ModifierPipeline = ModifierPipeline.new()
	var cowboy: Array[PerkInstance] = [PerkInstance.create(l.get_perk("perk_margin_cowboy"))]
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"leverage": 5, "trade_pnl": 100.0}, cowboy, _base(100.0))["payout"]), 140.0, 1e-9, "Margin Cowboy +0.4x at 5x")
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"leverage": 3, "trade_pnl": 100.0}, cowboy, _base(100.0))["payout"]), 100.0, 1e-9, "Margin Cowboy idle at 3x")
	var knife: Array[PerkInstance] = [PerkInstance.create(l.get_perk("perk_knife_catcher"))]
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"entry_regime": "CRASH", "trade_pnl": 100.0}, knife, _base(100.0))["payout"]), 200.0, 1e-9, "Knife Catcher x2 on CRASH entry")
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"entry_regime": "CALM", "trade_pnl": 100.0}, knife, _base(100.0))["payout"]), 100.0, 1e-9, "Knife Catcher idle outside CRASH")
	var hft: Array[PerkInstance] = [PerkInstance.create(l.get_perk("perk_hft_arbitrage"))]
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"trade_ticks_in_profit": 23, "trade_pnl": 100.0}, hft, _base(100.0))["payout"]), 100.0 + 4.0 * 300.0, 1e-9, "HFT +$300 per 5 ticks in profit")
	var flirt: Array[PerkInstance] = [PerkInstance.create(l.get_perk("perk_liquidation_flirt"))]
	var sess: Dictionary = pl.evaluate("ON_SESSION_END", {"min_margin": 0.2, "session_profit": 1000.0}, flirt, _base(1000.0))
	a.near(float(sess["payout"]), 3000.0, 1e-9, "Liquidation Flirt x3 session profit after dipping under 22%")
	a.near(float(pl.evaluate("ON_TRADE_CLOSE", {"min_margin": 0.2, "session_profit": 1000.0}, flirt, _base(1000.0))["payout"]), 1000.0, 1e-9, "session perks ignore trade closes")


func test_run_session_passives_and_guardian(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var rs: RunSession = RunSession.new(l.sim_config, l.stocks, RNGService.new(5), 10000.0)
	for id: String in ["perk_fiber_optic", "perk_forensic_accountant", "perk_stop_loss_guardian", "perk_bloomberg_trial"]:
		a.ok(rs.loadout.add_perk(l.get_perk(id)), "equip " + id)
	rs.apply_loadout()
	a.near(rs.portfolio.spread_mult, 0.0, 1e-12, "Fiber Optic Cable zeroes spread")
	a.near(float(rs.portfolio.sector_borrow_mult.get("MEME", 1.0)), 0.5, 1e-12, "Forensic Accountant halves Meme borrow")
	a.near(rs.momentum.wall_bonus_mult, 1.15, 1e-12, "Bloomberg Trial +15% wall bonus")
	rs.begin()
	var r: Dictionary = rs.open_position("OMNI", "LONG", 5, 1.0)
	var p: PositionState = r["position"]
	a.near(p.entry_price, float(rs.market.prices["OMNI"]), 1e-9, "zero-spread fill at mid")
	rs.portfolio.set_quote("OMNI", p.entry_price * (1.0 - 0.17), 0.0)
	rs._check_margin()
	a.eq(rs.portfolio.positions.size(), 0, "Stop-Loss Guardian closed the position before liquidation")
	a.ok(not rs.was_margin_called, "no margin call thanks to the guardian")
	a.eq(rs.loadout.get_perk("perk_stop_loss_guardian").charges, 0, "guardian charge consumed")
	rs.loadout.reset_quarter_charges()
	a.eq(rs.loadout.get_perk("perk_stop_loss_guardian").charges, 1, "charge restored each Quarter")
	rs.loadout.disabled_perk_ids = ["perk_fiber_optic"] as Array[String]
	rs.apply_loadout()
	a.near(rs.portfolio.spread_mult, 1.0, 1e-12, "boss-frozen perk stops applying")
