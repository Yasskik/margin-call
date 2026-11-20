class_name PortfolioState
extends RefCounted
## Cash, leveraged positions, borrow fees, equity, gross exposure and the real-time Margin Ratio
## M = E / G (Part 2.3), plus the [v1.1] preview_entry sizing contract (Part 2.3b).

signal position_opened(pos: PositionState)
signal position_closed(pos: PositionState, realized_pnl: float)

const EPS: float = 1e-9

var config: Dictionary
var cash: float = 0.0
var positions: Array[PositionState] = []
var stock_info: Dictionary = {} # ticker -> StockDef
var quotes: Dictionary = {}     # ticker -> {mid, spread_pct}
var dt: float = 0.0
var margin_safe: float = 0.25
var margin_liquidation: float = 0.15
var max_positions: int = 6
var leverage_options: Array[int] = []
var allow_10x: bool = false
var max_leverage_cap: int = 10
var shorts_enabled: bool = true
var spread_mult: float = 1.0          # Fiber Optic Cable -> 0
var borrow_mult: float = 1.0          # Prime Broker Squeeze -> 3
var sector_borrow_mult: Dictionary = {} # Forensic Accountant
var _next_id: int = 1


func _init(cfg: Dictionary, starting_cash: float, stocks: Array[StockDef]) -> void:
	config = cfg
	cash = starting_cash
	margin_safe = float(cfg["margin_safe"])
	margin_liquidation = float(cfg["margin_liquidation"])
	max_positions = int(cfg.get("max_open_positions", 6))
	for l: Variant in cfg.get("leverage_options", [1, 2, 3, 5, 10]):
		leverage_options.append(int(l))
	var ticks: float = float(cfg["ticks_per_second"]) * float(cfg["session_seconds"])
	dt = (float(cfg["session_sim_days"]) / float(cfg["trading_days_per_year"])) / ticks
	for s: StockDef in stocks:
		stock_info[s.ticker] = s
		quotes[s.ticker] = {"mid": s.start_price, "spread_pct": s.spread_pct}


func set_quote(ticker: String, mid: float, spread_pct: float) -> void:
	quotes[ticker] = {"mid": mid, "spread_pct": spread_pct}


func mid(ticker: String) -> float:
	return float(quotes[ticker]["mid"])


func bid(ticker: String) -> float:
	return mid(ticker) * (1.0 - float(quotes[ticker]["spread_pct"]) * spread_mult * 0.5)


func ask(ticker: String) -> float:
	return mid(ticker) * (1.0 + float(quotes[ticker]["spread_pct"]) * spread_mult * 0.5)


## Long: N (P_bid - P_entry)/P_entry.  Short: N (P_entry - P_ask)/P_entry - sum(borrow).
func position_pnl(p: PositionState, extra_slippage: float = 0.0) -> float:
	if p.is_long():
		var exit_px: float = bid(p.ticker) * (1.0 - extra_slippage)
		return p.notional * (exit_px - p.entry_price) / p.entry_price + p.dividends
	var cover_px: float = ask(p.ticker) * (1.0 + extra_slippage)
	return p.notional * (p.entry_price - cover_px) / p.entry_price - p.borrow_paid - p.dividends


func equity() -> float:
	var e: float = cash
	for p: PositionState in positions:
		e += p.collateral + position_pnl(p)
	return e


func gross_exposure() -> float:
	var g: float = 0.0
	for p: PositionState in positions:
		g += p.notional
	return g


func margin_ratio() -> float:
	var g: float = gross_exposure()
	if g <= 0.0:
		return 1.0
	return equity() / g


func zone_for(m: float) -> String:
	if m + EPS >= margin_safe:
		return "SAFE"
	if m + EPS >= margin_liquidation:
		return "WARNING"
	return "LIQUIDATION"


func zone() -> String:
	return zone_for(margin_ratio())


func allowed_leverages() -> Array[int]:
	var out: Array[int] = []
	for l: int in leverage_options:
		if l >= 10 and not allow_10x:
			continue
		if l > max_leverage_cap:
			continue
		out.append(l)
	return out


## Sizing preview (2.3b): returns margin_after, zone, allowed, reason, collateral, notional.
func preview_entry(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	var e: float = equity()
	var c: float = allocation_pct * e
	var n: float = c * float(leverage)
	var g_after: float = gross_exposure() + n
	var m_after: float = e / g_after if g_after > 0.0 else 1.0
	var z: String = zone_for(m_after)
	var res: Dictionary = {"margin_after": m_after, "zone": z, "allowed": false, "reason": "", "collateral": c, "notional": n}
	if not stock_info.has(ticker):
		res["reason"] = "Unknown ticker"
	elif side == "SHORT" and not shorts_enabled:
		res["reason"] = "Shorting disabled"
	elif positions.size() >= max_positions:
		res["reason"] = "Max %d open positions" % max_positions
	elif not allowed_leverages().has(leverage):
		res["reason"] = "%dx locked" % leverage
	elif leverage >= 2 and zone() != "SAFE":
		res["reason"] = "Margin Warning: deleverage first"
	elif e <= 0.0 or c <= 0.0:
		res["reason"] = "No equity"
	elif c > cash + 0.01:
		res["reason"] = "Not enough free cash"
	elif z == "LIQUIDATION":
		res["reason"] = "Would trigger instant liquidation"
	else:
		res["allowed"] = true
		res["reason"] = "Warning Zone entry" if z == "WARNING" else "OK"
	return res


func open_position(ticker: String, side: String, leverage: int, allocation_pct: float, tick: int = 0, regime: String = "CALM") -> Dictionary:
	var pv: Dictionary = preview_entry(ticker, side, leverage, allocation_pct)
	if not bool(pv["allowed"]):
		return {"ok": false, "reason": pv["reason"], "position": null}
	var p: PositionState = PositionState.new()
	p.id = "P%03d" % _next_id
	_next_id += 1
	p.ticker = ticker
	p.side = side
	p.leverage = leverage
	p.collateral = float(pv["collateral"])
	p.notional = float(pv["notional"])
	p.entry_price = ask(ticker) if side == "LONG" else bid(ticker)
	p.entry_mid = mid(ticker)
	p.entry_regime = regime
	p.opened_tick = tick
	cash -= p.collateral
	positions.append(p)
	p.unrealized_pnl = position_pnl(p)
	position_opened.emit(p)
	return {"ok": true, "reason": pv["reason"], "position": p, "margin_after": pv["margin_after"], "zone": pv["zone"]}


## Closes at bid (long) / ask (short), optional extra slippage (forced liquidation = 2%).
func close_position(pos_id: String, extra_slippage: float = 0.0) -> Dictionary:
	var p: PositionState = get_position(pos_id)
	if p == null:
		return {"ok": false, "realized_pnl": 0.0, "position": null}
	var pnl: float = position_pnl(p, extra_slippage)
	cash += p.collateral + pnl
	positions.erase(p)
	p.unrealized_pnl = pnl
	position_closed.emit(p, pnl)
	return {"ok": true, "realized_pnl": pnl, "position": p}


func liquidate_all(slippage: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: PositionState in positions.duplicate():
		out.append(close_position(p.id, slippage))
	return out


## Per-tick carry: short borrow fees (N * b * dt), dividends, unrealized PnL and hold stats.
func accrue_tick() -> void:
	for p: PositionState in positions:
		var s: StockDef = stock_info[p.ticker]
		if not p.is_long():
			var mult: float = borrow_mult * float(sector_borrow_mult.get(s.sector, 1.0))
			p.borrow_paid += p.notional * s.borrow_rate_annual * mult * dt
		if s.dividend_yield_annual > 0.0:
			p.dividends += p.notional * s.dividend_yield_annual * dt
		p.unrealized_pnl = position_pnl(p)
		p.peak_pnl = maxf(p.peak_pnl, p.unrealized_pnl)
		if p.unrealized_pnl > 0.0:
			p.ticks_in_profit += 1


func get_position(pos_id: String) -> PositionState:
	for p: PositionState in positions:
		if p.id == pos_id:
			return p
	return null


func held_tickers() -> Array[String]:
	var out: Array[String] = []
	for p: PositionState in positions:
		if not out.has(p.ticker):
			out.append(p.ticker)
	return out
