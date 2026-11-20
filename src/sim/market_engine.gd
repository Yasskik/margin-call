class_name MarketEngine
extends RefCounted
## Regime-switching GBM + Merton jump diffusion (Part 2.3 / 2.3a contract).
## Every parameter comes from the injected sim_config; all randomness from the injected RNGService.

signal tick_updated(ticker: String, price: float, bid: float, ask: float, regime: String, tick_idx: int)
signal regime_changed(old_regime: String, new_regime: String)
signal jump_warning_issued(ticker: String, seconds_ahead: float, direction_hint: int)
signal jump_event_announced(ticker: String, headline: String, impact_pct: float)
signal candle_closed(ticker: String, candle: Dictionary)
signal market_halted(ticker: String, halt_ticks: int)

const REGIMES: Array[String] = ["CALM", "BULL_MANIA", "VOLATILE", "CRASH"]
const MAX_CANDLES: int = 150

var config: Dictionary
var stocks: Array[StockDef] = []
var rng: RNGService
var dt: float = 0.0
var session_ticks: int = 450
var tick_idx: int = 0
var regime: String = "CALM"
var prices: Dictionary = {}       # ticker -> mid price
var session_open: Dictionary = {} # ticker -> mid at session start
var history: Dictionary = {}      # ticker -> Array[float] of mids this session (index 0 = open)
var candles: Dictionary = {}      # ticker -> Array[Dictionary] {o,h,l,c,regime}
var _building: Dictionary = {}    # ticker -> Dictionary candle in progress
var jumps: JumpScheduler

# --- Session modifiers (perks, bosses, tests) ---
var lock_regime: String = ""
var jumps_enabled: bool = true
var fed_whisperer: bool = false
var spread_mult: float = 1.0
var vol_mult: float = 1.0
var drift_add: float = 0.0
var circuit_threshold: float = 0.0
var circuit_halt_ticks: int = 0
var _halted_until: Dictionary = {}
var _circuit_ref: Dictionary = {}


func _init(cfg: Dictionary, stock_list: Array[StockDef], rng_service: RNGService) -> void:
	config = cfg
	stocks = stock_list
	rng = rng_service
	var tps: int = int(cfg["ticks_per_second"])
	session_ticks = tps * int(cfg["session_seconds"])
	dt = (float(cfg["session_sim_days"]) / float(cfg["trading_days_per_year"])) / float(session_ticks)
	jumps = JumpScheduler.new(cfg, rng, session_ticks)
	for s: StockDef in stocks:
		prices[s.ticker] = s.start_price
		candles[s.ticker] = [] as Array[Dictionary]


## Resets per-session state. Prices carry over between sessions (one continuous tape).
func start_session(start_regime: String = "") -> void:
	tick_idx = 0
	jumps.reset(fed_whisperer)
	_halted_until.clear()
	if lock_regime != "":
		regime = lock_regime
	elif start_regime != "":
		regime = start_regime
	else:
		regime = rng.weighted_pick(config["regime_start_weights"])
	for s: StockDef in stocks:
		var p: float = float(prices[s.ticker])
		session_open[s.ticker] = p
		_circuit_ref[s.ticker] = p
		var h: Array[float] = [p]
		history[s.ticker] = h
		_building[s.ticker] = {}


func is_session_over() -> bool:
	return tick_idx >= session_ticks


## Advances the whole market by exactly one tick.
func step() -> void:
	if is_session_over():
		return
	tick_idx += 1
	var interval: int = int(config["regime_check_interval_ticks"])
	if tick_idx % interval == 0 and lock_regime == "":
		var next: String = rng.weighted_pick(config["regime_transitions"][regime])
		if next != regime:
			var old: String = regime
			regime = next
			regime_changed.emit(old, next)
	for w: Dictionary in jumps.due_forced_warnings(tick_idx, stocks):
		jump_warning_issued.emit(str(w["ticker"]), float(w["seconds_ahead"]), int(w["direction_hint"]))
	for s: StockDef in stocks:
		_step_stock(s)


func _step_stock(s: StockDef) -> void:
	var t: String = s.ticker
	var p: float = float(prices[t])
	var z: float = rng.rand_gaussian()
	var roll: float = rng.randf()
	if int(_halted_until.get(t, 0)) < tick_idx:
		var sigma: float = effective_sigma(s)
		var mu: float = effective_mu(s)
		p *= exp((mu - 0.5 * sigma * sigma) * dt + sigma * sqrt(dt) * z)
		for j: Dictionary in jumps.pop_due(t, tick_idx):
			var y: float = float(j["log_size"])
			p *= exp(y)
			jump_event_announced.emit(t, _headline(s, y), exp(y) - 1.0)
		if jumps_enabled:
			var w: Dictionary = jumps.maybe_schedule(s, regime, roll, tick_idx)
			if not w.is_empty():
				jump_warning_issued.emit(t, float(w["seconds_ahead"]), int(w["direction_hint"]))
		p = maxf(p, 0.01)
		_check_circuit(t, p)
	prices[t] = p
	(history[t] as Array).append(p)
	_update_candle(t, p)
	var q: Dictionary = get_quote(t)
	tick_updated.emit(t, p, float(q["bid"]), float(q["ask"]), regime, tick_idx)


## sigma_eff = sigma_stock * m_r * boss vol mult (2.3a).
func effective_sigma(s: StockDef) -> float:
	var reg: Dictionary = config["regimes"][regime]
	return s.base_volatility * float(reg["vol_mult"]) * vol_mult


## mu_eff = G * [mu_stock + beta * (mu_r - mu_CALM)] (2.3a), plus boss drift shift.
func effective_mu(s: StockDef) -> float:
	var regs: Dictionary = config["regimes"]
	var mu_r: float = float(regs[regime]["drift"]) + drift_add
	var mu_calm: float = float(regs["CALM"]["drift"])
	return float(config["drift_game_scale"]) * (s.base_drift + s.regime_beta * (mu_r - mu_calm))


func get_quote(ticker: String) -> Dictionary:
	var mid: float = float(prices[ticker])
	var s: float = get_stock(ticker).spread_pct * spread_mult
	return {"mid": mid, "bid": mid * (1.0 - s * 0.5), "ask": mid * (1.0 + s * 0.5), "spread_pct": s}


func get_stock(ticker: String) -> StockDef:
	for s: StockDef in stocks:
		if s.ticker == ticker:
			return s
	return null


func session_return(ticker: String) -> float:
	return float(prices[ticker]) / float(session_open[ticker]) - 1.0


## Next-regime odds row (exposed for the Bloomberg Wall upgrade).
func next_regime_odds() -> Dictionary:
	return (config["regime_transitions"][regime] as Dictionary).duplicate()


func seconds_left() -> float:
	return float(session_ticks - tick_idx) / float(config["ticks_per_second"])


func _update_candle(t: String, p: float) -> void:
	var c: Dictionary = _building[t]
	if c.is_empty():
		c = {"o": p, "h": p, "l": p, "c": p, "regime": regime}
		_building[t] = c
	c["h"] = maxf(float(c["h"]), p)
	c["l"] = minf(float(c["l"]), p)
	c["c"] = p
	if tick_idx % int(config.get("candle_ticks", 5)) == 0:
		var list: Array = candles[t]
		list.append(c)
		if list.size() > MAX_CANDLES:
			list.pop_front()
		_building[t] = {}
		candle_closed.emit(t, c)


func building_candle(t: String) -> Dictionary:
	return _building.get(t, {})


func _check_circuit(t: String, p: float) -> void:
	if circuit_threshold <= 0.0:
		return
	var ref: float = float(_circuit_ref[t])
	if absf(p / ref - 1.0) > circuit_threshold:
		_halted_until[t] = tick_idx + circuit_halt_ticks
		_circuit_ref[t] = p
		market_halted.emit(t, circuit_halt_ticks)


func is_halted(t: String) -> bool:
	return int(_halted_until.get(t, 0)) >= tick_idx


func _headline(s: StockDef, y: float) -> String:
	var pool: Array = config.get("jump_headlines", {}).get("up" if y >= 0.0 else "down", ["{ticker} gaps"])
	var idx: int = int(absf(y) * 100000.0) % maxi(pool.size(), 1)
	return str(pool[idx]).replace("{ticker}", s.ticker).replace("{name}", s.name)
