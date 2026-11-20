extends RefCounted
## Stage 1 [v1.1] contract tests: (e) time-scale statistics, (f) sizing table, (g) jump warnings.


func _session_log_return_std(ticker: String, sessions: int) -> float:
	var l: DataLoader = TestHelpers.loader()
	var m: MarketEngine = MarketEngine.new(l.sim_config, TestHelpers.only(l.stocks, ticker), RNGService.new(424242))
	m.lock_regime = "CALM"
	m.jumps_enabled = false
	var rets: PackedFloat64Array = PackedFloat64Array()
	for i: int in sessions:
		m.start_session()
		while not m.is_session_over():
			m.step()
		rets.append(log(float(m.prices[ticker]) / float(m.session_open[ticker])))
	var mean: float = 0.0
	for r: float in rets:
		mean += r
	mean /= float(rets.size())
	var v: float = 0.0
	for r: float in rets:
		v += (r - mean) * (r - mean)
	return sqrt(v / float(rets.size() - 1))


## (e) CALM, no jumps, 300 seeded sessions: session log-return std within +/-15% of target.
func test_e_time_scale_statistics(a: TestAssert) -> void:
	var omni: float = _session_log_return_std("OMNI", 300)
	var memx: float = _session_log_return_std("MEMX", 300)
	print("    OMNI session std = %.4f (target 0.081), MEMX = %.4f (target 0.274)" % [omni, memx])
	a.ok(absf(omni / 0.081 - 1.0) <= 0.15, "OMNI std %.4f within 15%% of 0.081" % omni)
	a.ok(absf(memx / 0.274 - 1.0) <= 0.15, "MEMX std %.4f within 15%% of 0.274" % memx)


## (f) sizing table from Part 2.3b.
func test_f_preview_entry_sizing_table(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var pf: PortfolioState = PortfolioState.new(l.sim_config, 10000.0, l.stocks)
	a.ok(not bool(pf.preview_entry("OMNI", "LONG", 10, 0.1)["allowed"]), "10x locked by default (Prestige < 25)")
	pf.allow_10x = true
	var p40: Dictionary = pf.preview_entry("OMNI", "LONG", 10, 0.40)
	a.near(float(p40["margin_after"]), 0.25, 1e-9, "10x @ 40% -> M_after = 0.25")
	a.eq(str(p40["zone"]), "SAFE", "10x @ 40% stays in Safe Zone")
	a.ok(bool(p40["allowed"]), "10x @ 40% allowed")
	var p70: Dictionary = pf.preview_entry("OMNI", "LONG", 10, 0.70)
	a.ok(not bool(p70["allowed"]), "10x @ 70% rejected (would self-liquidate)")
	a.eq(str(p70["zone"]), "LIQUIDATION", "10x @ 70% zone")
	var p5: Dictionary = pf.preview_entry("OMNI", "LONG", 5, 1.0)
	a.near(float(p5["margin_after"]), 0.20, 1e-9, "5x @ 100% -> M_after = 0.20")
	a.eq(str(p5["zone"]), "WARNING", "5x @ 100% reports Warning Zone")
	a.ok(bool(p5["allowed"]), "Warning Zone entries are allowed (with warning)")
	var p3: Dictionary = pf.preview_entry("OMNI", "SHORT", 3, 1.0)
	a.eq(str(p3["zone"]), "SAFE", "3x @ 100% safe")
	a.near(float(pf.preview_entry("OMNI", "LONG", 10, 0.6667)["margin_after"]), 1.0 / 6.667, 1e-6, "10x @ 66.7% ~ 0.15")
	pf.max_leverage_cap = 3
	a.ok(not bool(pf.preview_entry("OMNI", "LONG", 5, 0.1)["allowed"]), "boss leverage cap blocks 5x")
	pf.max_leverage_cap = 10
	pf.shorts_enabled = false
	a.ok(not bool(pf.preview_entry("OMNI", "SHORT", 1, 0.1)["allowed"]), "short ban blocks shorts")


func _jump_audit(fed: bool, a: TestAssert, expected_lead: int) -> void:
	var l: DataLoader = TestHelpers.loader()
	var m: MarketEngine = MarketEngine.new(l.sim_config, l.stocks, RNGService.new(9001))
	m.lock_regime = "VOLATILE"
	m.fed_whisperer = fed
	var warnings: Array[Dictionary] = []
	var jumps: Array[Dictionary] = []
	var on_warn: Callable = func(t: String, secs: float, hint: int) -> void:
		warnings.append({"ticker": t, "tick": m.tick_idx, "secs": secs, "hint": hint})
	var on_jump: Callable = func(t: String, _h: String, impact: float) -> void:
		jumps.append({"ticker": t, "tick": m.tick_idx, "impact": impact})
	m.jump_warning_issued.connect(on_warn)
	m.jump_event_announced.connect(on_jump)
	for i: int in 30:
		m.start_session()
		var w_start: int = warnings.size()
		var j_start: int = jumps.size()
		while not m.is_session_over():
			m.step()
		for j: int in range(j_start, jumps.size()):
			var jump: Dictionary = jumps[j]
			var matches: int = 0
			for w: int in range(w_start, warnings.size()):
				var warn: Dictionary = warnings[w]
				if warn["ticker"] == jump["ticker"] and int(warn["tick"]) == int(jump["tick"]) - expected_lead:
					matches += 1
					if fed:
						a.eq(int(warn["hint"]), 1 if float(jump["impact"]) >= 0.0 else -1, "Fed Whisperer hint matches direction")
					else:
						a.eq(int(warn["hint"]), 0, "direction hidden without Fed Whisperer")
			a.eq(matches, 1, "jump %s@%d preceded by exactly one warning %d ticks earlier" % [jump["ticker"], jump["tick"], expected_lead])
		a.eq(warnings.size() - w_start, jumps.size() - j_start, "every warning resolves into a jump within the session")
	m.jump_warning_issued.disconnect(on_warn)
	m.jump_event_announced.disconnect(on_jump)
	a.ok(jumps.size() > 50, "VOLATILE regime produced plenty of jumps (%d)" % jumps.size())
	if not warnings.is_empty():
		a.near(float(warnings[0]["secs"]), float(expected_lead) / 10.0, 1e-9, "seconds_ahead reported")


## (g) every jump is preceded by exactly one warning 15 ticks earlier (30 with Fed Whisperer).
func test_g_jump_warnings(a: TestAssert) -> void:
	_jump_audit(false, a, 15)
	_jump_audit(true, a, 30)


## Regime Markov chain actually switches and stays deterministic.
func test_regime_switching_and_forced_jumps(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var m: MarketEngine = MarketEngine.new(l.sim_config, l.stocks, RNGService.new(55))
	var seen: Dictionary = {}
	m.regime_changed.connect(func(_o: String, n: String) -> void: seen[n] = true)
	for i: int in 40:
		m.start_session()
		while not m.is_session_over():
			m.step()
	a.ok(seen.size() >= 3, "Markov chain visits at least 3 regimes over 40 sessions (%d)" % seen.size())
	var calm: StockDef = m.get_stock("OMNI")
	m.regime = "CRASH"
	a.near(m.effective_mu(calm), 4.0 * (0.12 + 1.0 * (-0.60 - 0.08)), 1e-12, "mu_eff = G[mu + beta(mu_r - mu_calm)]")
	a.near(m.effective_sigma(calm), 0.28 * 2.17, 1e-12, "sigma_eff = sigma * m_r")
	var forced: MarketEngine = MarketEngine.new(l.sim_config, l.stocks, RNGService.new(3))
	forced.jumps_enabled = false
	forced.jumps.set_forced([{"tick": 200, "ticker": "ALL", "size_std": 0.10}] as Array[Dictionary])
	var fired: Array[int] = []
	var warned: Array[int] = []
	var on_fire: Callable = func(_t: String, _h: String, _i: float) -> void: fired.append(forced.tick_idx)
	var on_warned: Callable = func(_t: String, _s: float, _h: int) -> void: warned.append(forced.tick_idx)
	forced.jump_event_announced.connect(on_fire)
	forced.jump_warning_issued.connect(on_warned)
	forced.start_session()
	while not forced.is_session_over():
		forced.step()
	forced.jump_event_announced.disconnect(on_fire)
	forced.jump_warning_issued.disconnect(on_warned)
	a.eq(fired.size(), 8, "CPI Print forced jump hits all 8 tickers")
	a.ok(fired.has(200) and warned.has(185), "forced jump fires at t=20s with a 1.5s warning")
