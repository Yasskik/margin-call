extends RefCounted
## Stage 1 deterministic pricing, leverage and liquidation tests: (a) (b) (c) (d) (h).


func _engine(seed_value: int) -> MarketEngine:
	var l: DataLoader = TestHelpers.loader()
	return MarketEngine.new(l.sim_config, l.stocks, RNGService.new(seed_value))


func _path(seed_value: int) -> PackedFloat64Array:
	var m: MarketEngine = _engine(seed_value)
	m.start_session()
	var out: PackedFloat64Array = PackedFloat64Array()
	for i: int in m.session_ticks:
		m.step()
		for s: StockDef in m.stocks:
			out.append(float(m.prices[s.ticker]))
	out.append(float(m.tick_idx))
	return out


## (a) identical seeds produce identical 450-tick paths; different seeds differ.
func test_a_identical_seeds_identical_paths(a: TestAssert) -> void:
	var p1: PackedFloat64Array = _path(1337)
	var p2: PackedFloat64Array = _path(1337)
	var p3: PackedFloat64Array = _path(1338)
	a.eq(p1.size(), 450 * 8 + 1, "450 ticks x 8 tickers recorded")
	a.ok(p1 == p2, "same seed -> bit-identical path")
	a.ok(p1 != p3, "different seed -> different path")
	var m: MarketEngine = _engine(7)
	m.start_session()
	while not m.is_session_over():
		m.step()
	a.eq(m.tick_idx, 450, "session is exactly 450 ticks")
	a.eq((m.candles["OMNI"] as Array).size(), 90, "5-tick candles -> 90 per session")
	a.near(m.dt, (21.0 / 252.0) / 450.0, 1e-15, "dt = (21/252)/450 years per tick")


## (b) exact 5x Long and Short PnL including spread and borrow fees.
func test_b_exact_5x_long_short_pnl(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var stocks: Array[StockDef] = [TestHelpers.make_stock("TST", 100.0, 0.001, 0.05)]
	var pf: PortfolioState = PortfolioState.new(l.sim_config, 10000.0, stocks)
	pf.set_quote("TST", 100.0, 0.001)
	var r: Dictionary = pf.open_position("TST", "LONG", 5, 0.5)
	a.ok(bool(r["ok"]), "5x long at 50% opens")
	var p: PositionState = r["position"]
	a.near(p.collateral, 5000.0, 1e-9, "collateral = 50% of equity")
	a.near(p.notional, 25000.0, 1e-9, "notional = C * L")
	a.near(p.entry_price, 100.05, 1e-9, "long enters at ask")
	a.near(pf.cash, 5000.0, 1e-9, "cash debited by collateral")
	pf.set_quote("TST", 110.0, 0.001)
	var expected_long: float = 25000.0 * (109.945 - 100.05) / 100.05
	a.near(pf.position_pnl(p), expected_long, 1e-6, "long PnL marks at bid")
	var c: Dictionary = pf.close_position(p.id)
	a.near(float(c["realized_pnl"]), expected_long, 1e-6, "long realized PnL exact")
	a.near(pf.cash, 10000.0 + expected_long, 1e-6, "cash after long close")

	var pf2: PortfolioState = PortfolioState.new(l.sim_config, 10000.0, stocks)
	pf2.set_quote("TST", 100.0, 0.001)
	var r2: Dictionary = pf2.open_position("TST", "SHORT", 5, 0.5)
	var s: PositionState = r2["position"]
	a.near(s.entry_price, 99.95, 1e-9, "short enters at bid")
	for i: int in 100:
		pf2.accrue_tick()
	var fee: float = 25000.0 * 0.05 * pf2.dt * 100.0
	a.near(s.borrow_paid, fee, 1e-9, "borrow fee = N * b * dt per tick")
	pf2.set_quote("TST", 90.0, 0.001)
	var expected_short: float = 25000.0 * (99.95 - 90.045) / 99.95 - fee
	a.near(pf2.position_pnl(s), expected_short, 1e-6, "short PnL covers at ask minus borrow")
	var c2: Dictionary = pf2.close_position(s.id)
	a.near(float(c2["realized_pnl"]), expected_short, 1e-6, "short realized PnL exact")


## (c) Margin Warning at 24.9% and Forced Liquidation at 14.9% (with 2% slippage).
func test_c_margin_warning_and_liquidation(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var stocks: Array[StockDef] = [TestHelpers.make_stock("TST", 100.0, 0.0, 0.0)]
	var pf: PortfolioState = PortfolioState.new(l.sim_config, 10000.0, stocks)
	pf.set_quote("TST", 100.0, 0.0)
	var r: Dictionary = pf.open_position("TST", "LONG", 3, 1.0)
	var p: PositionState = r["position"]
	a.near(pf.margin_ratio(), 10000.0 / 30000.0, 1e-12, "M = E / G after entry")
	a.eq(pf.zone(), "SAFE", "33% margin is SAFE")
	# E = 0.249 * 30000 = 7470 -> PnL = -2530 -> price = 100 * (1 - 2530/30000)
	pf.set_quote("TST", 100.0 * (1.0 - 2530.0 / 30000.0), 0.0)
	a.near(pf.margin_ratio(), 0.249, 1e-9, "M = 24.9%")
	a.eq(pf.zone(), "WARNING", "24.9% -> Margin Warning")
	a.ok(not bool(pf.preview_entry("TST", "LONG", 2, 0.1)["allowed"]), "leveraged entries locked in Warning Zone")
	pf.set_quote("TST", 100.0 * (1.0 - 2500.0 / 30000.0), 0.0)
	a.near(pf.margin_ratio(), 0.25, 1e-9, "M = 25.0%")
	a.eq(pf.zone(), "SAFE", "25.0% is back in the Safe Zone")
	pf.set_quote("TST", 100.0 * (1.0 - 5530.0 / 30000.0), 0.0)
	a.near(pf.margin_ratio(), 0.149, 1e-9, "M = 14.9%")
	a.eq(pf.zone(), "LIQUIDATION", "14.9% -> Forced Liquidation")
	var px: float = 100.0 * (1.0 - 5530.0 / 30000.0)
	var expected: float = 30000.0 * (px * 0.98 - 100.0) / 100.0
	var res: Array[Dictionary] = pf.liquidate_all(float(l.sim_config["forced_liquidation_slippage"]))
	a.eq(res.size(), 1, "one position liquidated")
	a.near(float(res[0]["realized_pnl"]), expected, 1e-6, "liquidation applies 2% forced slippage")
	a.eq(pf.positions.size(), 0, "book is flat after liquidation")
	a.near(pf.cash, 10000.0 + expected, 1e-6, "cash reflects liquidation loss")
	a.eq(p.id, "P001", "position ids are sequential")


## (d) Resistance Wall smash detection, tier advancement and WallBonus formula.
func test_d_wall_smash_and_tiers(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	var me: MomentumEngine = MomentumEngine.new(l.sim_config["momentum"])
	var p: PositionState = PositionState.new()
	p.id = "P1"
	p.ticker = "TST"
	p.side = "LONG"
	p.leverage = 5
	p.notional = 50000.0
	p.entry_mid = 100.0
	me.register_position(p, [0.04, 0.09, 0.16, 0.25, 0.38] as Array[float])
	a.eq(me.check_walls(p, 103.99).size(), 0, "no smash below +4% wall")
	var e1: Array[Dictionary] = me.check_walls(p, 104.0)
	a.eq(e1.size(), 1, "smash at +4% wall")
	a.eq(int(e1[0]["tier"]), 1, "tier 1")
	a.near(float(e1[0]["bonus"]), 0.05 * 50000.0 * 1.0, 1e-9, "WallBonus_1 = 0.05 * N * 1 at K=0")
	me.momentum = 50.0
	var e2: Array[Dictionary] = me.check_walls(p, 117.0)
	a.eq(e2.size(), 2, "jump through two walls smashes both")
	a.eq(int(e2[1]["tier"]), 3, "tier advances to 3")
	a.near(float(e2[0]["bonus"]), 0.05 * 50000.0 * 2.0 * 1.5, 1e-9, "WallBonus_2 with K=50")
	a.eq(p.wall_tier, 3, "position wall tier = 3")
	a.eq(me.session_walls_broken, 3, "session wall counter")
	a.eq(me.check_walls(p, 117.0).size(), 0, "walls do not re-trigger")
	var s: PositionState = PositionState.new()
	s.id = "P2"
	s.side = "SHORT"
	s.leverage = 2
	s.notional = 20000.0
	s.entry_mid = 100.0
	me.register_position(s, [0.04, 0.09] as Array[float])
	a.eq(me.check_walls(s, 95.0).size(), 1, "short smashes -4% support floor")
	a.eq(me.session_floors_broken, 1, "floor counter")
	var one_x: PositionState = PositionState.new()
	one_x.id = "P3"
	one_x.leverage = 1
	one_x.entry_mid = 100.0
	me.register_position(one_x, [0.04] as Array[float])
	a.ok(not me.has_ladder("P3"), "1x positions have no wall ladder (needs leverage)")


## (h) every regime_transitions row in sim_config.json sums to 1.0; bad rows are rejected.
func test_h_transition_rows_sum_to_one(a: TestAssert) -> void:
	var l: DataLoader = TestHelpers.loader()
	a.ok(l.is_valid(), "data registry loads with zero errors: " + "; ".join(l.errors))
	var trans: Dictionary = l.sim_config["regime_transitions"]
	for r: String in DataLoader.REGIME_NAMES:
		var total: float = 0.0
		for v: Variant in (trans[r] as Dictionary).values():
			total += float(v)
		a.near(total, 1.0, 0.001, "row %s sums to 1" % r)
	var bad: Dictionary = l.sim_config.duplicate(true)
	bad["regime_transitions"]["CALM"]["CALM"] = 0.5
	print("    (the next push_error is EXPECTED: validator rejecting a malformed row)")
	var probe: DataLoader = DataLoader.new()
	a.ok(not probe.validate_sim_config(bad), "validator rejects a row that sums to 0.65")
	a.eq(l.stocks.size(), 8, "8 launch tickers")
	a.eq(l.bosses.size(), 12, "12 quarterly bosses")
