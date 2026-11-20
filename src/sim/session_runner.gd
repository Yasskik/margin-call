class_name SessionRunner
extends RefCounted
## Composes MarketEngine + PortfolioState + MomentumEngine into one 450-tick trading session.
## Pure logic: the UI drives `step()` at 10 Hz and listens to these typed signals via EventBridge.

signal wall_smashed(ticker: String, wall_tier: int, wall_price: float, bonus_cash: float, momentum: float)
signal portfolio_updated(cash: float, equity: float, gross_exposure: float, margin_ratio: float)
signal margin_warning_changed(is_warning: bool, margin_ratio: float)
signal margin_called(final_equity: float)
signal position_opened(pos_id: String, ticker: String, side: String, leverage: int, collateral: float)
signal position_closed(pos_id: String, realized_pnl: float, trigger_steps: Array)
signal session_finished(summary: Dictionary)

var config: Dictionary
var market: MarketEngine
var portfolio: PortfolioState
var momentum: MomentumEngine
var active: bool = false
var is_warning: bool = false
var was_margin_called: bool = false
var session_realized: float = 0.0
var min_margin: float = 1.0
var trades_closed: int = 0
var best_combo: float = 0.0
var crash_red_candles: int = 0
var start_equity: float = 0.0


func _init(cfg: Dictionary, stocks: Array[StockDef], rng: RNGService, starting_cash: float) -> void:
	config = cfg
	market = MarketEngine.new(cfg, stocks, rng)
	portfolio = PortfolioState.new(cfg, starting_cash, stocks)
	momentum = MomentumEngine.new(cfg.get("momentum", {}))
	market.candle_closed.connect(_on_candle_closed)
	_sync_quotes()


func begin(start_regime: String = "") -> void:
	market.start_session(start_regime)
	momentum.reset_session()
	_sync_quotes()
	active = true
	is_warning = false
	was_margin_called = false
	session_realized = 0.0
	min_margin = 1.0
	trades_closed = 0
	best_combo = 0.0
	crash_red_candles = 0
	start_equity = portfolio.equity()
	_emit_portfolio()


func step() -> void:
	if not active:
		return
	market.step()
	_sync_quotes()
	portfolio.accrue_tick()
	for e: Dictionary in momentum.update(portfolio.positions, market.history):
		wall_smashed.emit(str(e["ticker"]), int(e["tier"]), float(e["wall_price"]), float(e["bonus"]), float(e["momentum"]))
		_on_wall_event(e)
	_check_margin()
	_emit_portfolio()
	if market.is_session_over():
		finish()


func preview_entry(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	return portfolio.preview_entry(ticker, side, leverage, allocation_pct)


func open_position(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	if not active:
		return {"ok": false, "reason": "Market closed"}
	var res: Dictionary = portfolio.open_position(ticker, side, leverage, allocation_pct, market.tick_idx, market.regime)
	if bool(res["ok"]):
		var p: PositionState = res["position"]
		momentum.register_position(p, market.get_stock(ticker).wall_offsets_pct)
		position_opened.emit(p.id, p.ticker, p.side, p.leverage, p.collateral)
		_on_position_opened(p)
		_emit_portfolio()
	return res


## Closes at market, resolves the trade through the payout resolver and credits the difference.
func close_position(pos_id: String) -> Dictionary:
	var r: Dictionary = portfolio.close_position(pos_id)
	if not bool(r["ok"]):
		return r
	var p: PositionState = r["position"]
	momentum.unregister(pos_id)
	var raw: float = float(r["realized_pnl"])
	var resolved: Dictionary = resolve_trade(p, raw)
	var payout: float = float(resolved["payout"])
	portfolio.cash += payout - raw
	session_realized += payout
	trades_closed += 1
	best_combo = maxf(best_combo, payout)
	r["payout"] = payout
	r["steps"] = resolved["steps"]
	position_closed.emit(pos_id, payout, resolved["steps"])
	_emit_portfolio()
	return r


## Trade resolution hook. Stage 2: Base Alpha only (raw PnL + wall bonuses).
## Stage 3 RunSession overrides this with the ordered 4-phase ModifierPipeline.
func resolve_trade(p: PositionState, raw_pnl: float) -> Dictionary:
	var base: float = raw_pnl + p.wall_bonus
	var step: TriggerStep = TriggerStep.make("BASE", "Base Profit", "BASE_ALPHA", base, "#00E676")
	step.running_total = base
	var steps: Array = [step]
	return {"payout": base, "steps": steps}


## Session settlement hook (Stage 3 adds ON_SESSION_END perks).
func resolve_session() -> Dictionary:
	return {"bonus": 0.0, "steps": []}


func finish() -> void:
	if not active:
		return
	var closes: Array[Dictionary] = []
	for p: PositionState in portfolio.positions.duplicate():
		closes.append(close_position(p.id))
	var settle: Dictionary = resolve_session()
	portfolio.cash += float(settle["bonus"])
	session_realized += float(settle["bonus"])
	active = false
	_emit_portfolio()
	session_finished.emit({
		"closes": closes, "settlement_steps": settle["steps"], "settlement_bonus": settle["bonus"],
		"session_realized": session_realized, "equity": portfolio.equity(), "start_equity": start_equity,
		"min_margin": min_margin, "walls": momentum.session_walls_broken, "floors": momentum.session_floors_broken,
		"trades": trades_closed, "best_combo": best_combo, "margin_called": was_margin_called,
	})


func _check_margin() -> void:
	if portfolio.positions.is_empty():
		if is_warning:
			is_warning = false
			margin_warning_changed.emit(false, 1.0)
		return
	var m: float = portfolio.margin_ratio()
	min_margin = minf(min_margin, m)
	if _pre_margin_check(m):
		m = portfolio.margin_ratio()
	var z: String = portfolio.zone_for(m)
	if z == "LIQUIDATION":
		var res: Array[Dictionary] = portfolio.liquidate_all(float(config["forced_liquidation_slippage"]))
		for r: Dictionary in res:
			var p: PositionState = r["position"]
			momentum.unregister(p.id)
			session_realized += float(r["realized_pnl"])
			position_closed.emit(p.id, float(r["realized_pnl"]), [])
		was_margin_called = true
		momentum.reset_momentum()
		margin_called.emit(portfolio.equity())
		if is_warning:
			is_warning = false
			margin_warning_changed.emit(false, portfolio.margin_ratio())
		return
	var warn: bool = z == "WARNING"
	if warn != is_warning:
		is_warning = warn
		margin_warning_changed.emit(warn, m)


## Defensive hook before liquidation (Stop-Loss Guardian). Returns true if it acted.
func _pre_margin_check(_m: float) -> bool:
	return false


func _on_wall_event(_e: Dictionary) -> void:
	pass


func _on_position_opened(_p: PositionState) -> void:
	pass


func _on_candle_closed(ticker: String, candle: Dictionary) -> void:
	if str(candle["regime"]) != "CRASH":
		return
	if float(candle["c"]) < float(candle["o"]) and portfolio.held_tickers().has(ticker):
		crash_red_candles += 1


func _sync_quotes() -> void:
	for s: StockDef in market.stocks:
		var q: Dictionary = market.get_quote(s.ticker)
		portfolio.set_quote(s.ticker, float(q["mid"]), float(q["spread_pct"]))


func _emit_portfolio() -> void:
	portfolio_updated.emit(portfolio.cash, portfolio.equity(), portfolio.gross_exposure(), portfolio.margin_ratio())
