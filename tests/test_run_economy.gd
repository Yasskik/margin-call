extends RefCounted
## Stage 4A: deterministic Q1 -> Q4 progression, tax & burn math, insolvency, reroll curve,
## 50% sellback and boss modifier application.


func _loader_with_targets(target: float, burn: float = -1.0) -> DataLoader:
	var l: DataLoader = TestHelpers.loader()
	for b: Dictionary in l.bosses:
		b["target_equity"] = target
		if burn >= 0.0:
			b["burn_rate"] = burn
	return l


func _play_session(r: RunController, ticker_calm: String) -> void:
	while r.phase == "TRADING":
		var t: int = r.session.market.tick_idx
		if t == 5:
			var tk: String = "APEX" if r.session.market.regime == "CRASH" else ticker_calm
			r.open_position(tk, "LONG", 2, 0.25)
		elif t == 300:
			for p: PositionState in r.session.portfolio.positions.duplicate():
				r.close_position(p.id)
		r.advance_tick()


## Simple visible-information bot; returns a trace of (phase, quarter, session, equity cents).
func _bot_run(l: DataLoader, seed_value: int, stop_quarter: int) -> Array[String]:
	var r: RunController = RunController.new(l, seed_value)
	var trace: Array[String] = []
	r.start_run()
	var guard: int = 0
	while guard < 200 and r.phase != "GAME_OVER" and r.phase != "VICTORY" and r.quarter < stop_quarter:
		guard += 1
		match r.phase:
			"TRADING":
				_play_session(r, "OMNI")
			"SETTLEMENT":
				trace.append("S Q%d.%d %d" % [r.quarter, r.session_idx, int(round(r.session.portfolio.equity() * 100.0))])
				r.continue_from_settlement()
			"BOSS_AUDIT":
				trace.append("A Q%d %s %d" % [r.quarter, str(r.last_audit["passed"]), int(round(float(r.last_audit["net"]) * 100.0))])
				r.continue_from_audit()
			"AFTER_HOURS":
				if not r.shop.offers.is_empty() and r.session.portfolio.cash > 3.0 * float(r.shop.offers[0]["cost"]):
					r.buy_shop_item(0)
				r.next_session()
	trace.append("END %s Q%d" % [r.phase, r.quarter])
	return trace


func test_deterministic_q1_to_q4_progression(a: TestAssert) -> void:
	# Zero target + zero burn override: progression mechanics only (economy math is tested below).
	var l: DataLoader = _loader_with_targets(0.0, 0.0)
	var t1: Array[String] = _bot_run(l, 20261120, 5)
	var t2: Array[String] = _bot_run(l, 20261120, 5)
	var t3: Array[String] = _bot_run(l, 777, 5)
	a.ok(t1 == t2, "same seed -> identical Q1..Q4 trace")
	a.ok(t1 != t3, "different seed -> different trace")
	a.eq(t1[t1.size() - 1], "END AFTER_HOURS Q5", "cleared all four slice quarters (reached Q5 after-hours)")
	var audits: int = 0
	for line: String in t1:
		if line.begins_with("A "):
			audits += 1
	a.eq(audits, 4, "four boss audits (Q1-Q4)")
	a.eq(t1.size(), 4 * 4 + 4 + 1, "3 sessions + boss per quarter, plus audits")


func test_tax_and_burn_math(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var q: QuarterRules = QuarterRules.new(l.sim_config, l.bosses)
	a.near(q.capital_gains_tax(10000.0, 0.0), 1500.0, 1e-9, "15% capital gains tax")
	a.near(q.capital_gains_tax(10000.0, 0.10), 2500.0, 1e-9, "Year-End Tax Harvest +10%")
	a.near(q.capital_gains_tax(-4000.0, 0.0), 0.0, 1e-9, "no tax on a losing quarter")
	var ok: Dictionary = q.audit(20000.0, 15000.0, 1500.0, 1500.0)
	a.ok(bool(ok["passed"]), "20k - 3k = 17k clears 15k target")
	a.near(float(ok["net"]), 17000.0, 1e-9, "net equity after burn + tax")
	var low: Dictionary = q.audit(17000.0, 15000.0, 1500.0, 1500.0)
	a.ok(not bool(low["passed"]), "14k net misses the 15k target")
	a.eq(str(low["reason"]), "BELOW TARGET EQUITY", "insolvency reason")
	a.eq(str(q.audit(1000.0, 0.0, 1500.0, 0.0)["reason"]), "CANNOT COVER BURN + TAX", "cannot cover burn")
	var life: LifeSimState = LifeSimState.new(l.sim_config["economy"], l.lifestyle_upgrades)
	a.near(life.burn_rate(1500.0), 1500.0, 1e-9, "base burn with starter lifestyle")
	life.burn_rate_mult = 2.5
	a.near(life.burn_rate(1500.0), 3750.0, 1e-9, "Trust Fund Heir 2.5x burn")
	life.own_upgrade("house_midtown_loft")
	a.near(life.burn_rate(1500.0), 3750.0 + 2500.0, 1e-9, "lifestyle burn adds")
	a.near(life.prestige, 20.0, 1e-9, "Midtown Loft +20 Prestige")
	a.eq(life.shop_tier(), 0, "20 Prestige = Retail tier")
	life.add_prestige(5.0)
	a.eq(life.shop_tier(), 1, "25 Prestige = Hedge Fund tier")
	a.eq(life.stress(), 0.0, "Stage 4A stress placeholder")


func test_insolvency_detection(a: TestAssert) -> void:
	var l: DataLoader = _loader_with_targets(1.0e12)
	var r: RunController = RunController.new(l, 99)
	var ended: Array[String] = []
	r.run_ended.connect(func(o: String, _s: Dictionary) -> void: ended.append(o))
	r.start_run()
	for i: int in 3:
		_play_session(r, "OMNI")
		r.continue_from_settlement()
		r.next_session()
	a.ok(r.is_boss_session(), "fourth session of the quarter is the Boss")
	_play_session(r, "OMNI")
	r.continue_from_settlement()
	a.eq(r.phase, "BOSS_AUDIT", "boss settlement leads to the audit")
	a.ok(not bool(r.last_audit["passed"]), "impossible target fails the audit")
	r.continue_from_audit()
	a.eq(r.phase, "GAME_OVER", "failed audit -> GAME_OVER")
	a.eq(ended, ["INSOLVENCY"] as Array[String], "run_ended(INSOLVENCY)")


func test_reroll_curve_and_sellback(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var r: RunController = RunController.new(l, 4242)
	r.start_run()
	_play_session(r, "OMNI")
	r.continue_from_settlement()
	a.eq(r.phase, "AFTER_HOURS", "normal session -> After-Hours shop")
	a.eq(r.shop.offers.size(), 4, "4 shop offers")
	for o: Dictionary in r.shop.offers:
		var d: PerkDef = l.get_perk(str(o["id"]))
		a.ok(d != null and d.requires_feature == "" and d.min_prestige == 0, "only live, unlocked perks offered (%s)" % str(o["id"]))
	r.session.portfolio.cash = 50000.0
	a.eq(r.shop.reroll_cost(1), 400, "Q1 reroll #1 = $400")
	r.reroll_shop()
	a.eq(r.shop.reroll_cost(1), 700, "reroll #2 = $700")
	r.reroll_shop()
	a.eq(r.shop.reroll_cost(1), 1000, "reroll #3 = $1,000")
	a.near(r.session.portfolio.cash, 50000.0 - 400.0 - 700.0, 1e-9, "reroll costs deducted")
	a.eq(r.shop.reroll_cost(3), 800 + 600, "Q3 base scales x2 (+ step x2)")
	var locked_id: String = str(r.shop.offers[1]["id"])
	r.toggle_lock(1)
	r.reroll_shop()
	a.eq(str(r.shop.offers[0]["id"]), locked_id, "locked offer survives a reroll")
	var cost: int = int(r.shop.offers[2]["cost"])
	var bought_id: String = str(r.shop.offers[2]["id"])
	var before: float = r.session.portfolio.cash
	a.ok(bool(r.buy_shop_item(2)["ok"]), "buy offer")
	a.near(r.session.portfolio.cash, before - float(cost), 1e-9, "price paid")
	var res: Dictionary = r.sell_perk(bought_id)
	a.eq(int(res["refund"]), int(floor(float(cost) * 0.5)), "50% sellback")
	a.near(r.session.portfolio.cash, before - float(cost) + floor(float(cost) * 0.5), 1e-9, "cash after sellback")
	r.next_session()
	_play_session(r, "OMNI")
	r.continue_from_settlement()
	a.eq(r.shop.rerolls_this_visit, 0, "reroll curve resets each visit")
	a.ok(r.shop.offers.any(func(o: Dictionary) -> bool: return str(o["id"]) == locked_id), "lock persists to the next visit")


func test_boss_modifiers_apply_and_clear(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var r: RunController = RunController.new(l, 1)
	r.start_run()
	for i: int in 3:
		_play_session(r, "OMNI")
		r.continue_from_settlement()
		r.next_session()
	a.near(r.session.market.spread_mult, 2.0, 1e-12, "Q1 Retail Chop doubles spreads in the Boss session")
	var rules: QuarterRules = r.rules
	var s: RunSession = r.session
	rules.clear_boss(s)
	a.near(s.market.spread_mult, 1.0, 1e-12, "boss knobs restored")
	rules.apply_boss(s, rules.resolve_modifiers(rules.boss_for(3), r.boss_rng), r.boss_rng)
	a.ok(not s.portfolio.shorts_enabled, "Q3 Short Sale Restriction")
	rules.clear_boss(s)
	var fx: Dictionary = rules.apply_boss(s, rules.resolve_modifiers(rules.boss_for(4), r.boss_rng), r.boss_rng)
	a.near(float(fx["tax_rate_add"]), 0.10, 1e-12, "Q4 tax +10%")
	rules.clear_boss(s)
	rules.apply_boss(s, rules.resolve_modifiers(rules.boss_for(6), r.boss_rng), r.boss_rng)
	a.eq(s.loadout.disabled_perk_ids, ["perk_bloomberg_trial"] as Array[String], "Q6 freezes the leftmost perk")
	rules.clear_boss(s)
	rules.apply_boss(s, rules.resolve_modifiers(rules.boss_for(9), r.boss_rng), r.boss_rng)
	a.eq(s.portfolio.max_leverage_cap, 3, "Q9 caps leverage at 3x")
	rules.clear_boss(s)
	var q12: Array[Dictionary] = rules.resolve_modifiers(rules.boss_for(12), r.boss_rng)
	a.ok(q12.size() >= 2, "Q12 resolves two random boss modifier sets")
	a.eq(l.bosses.size(), 12, "all 12 bosses data-complete")
