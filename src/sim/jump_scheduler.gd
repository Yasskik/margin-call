class_name JumpScheduler
extends RefCounted
## Merton jump scheduling with the [v1.1] warning contract: a jump is rolled, its size drawn
## immediately (deterministic replays), and it fires `warning_ticks` later.

var config: Dictionary
var rng: RNGService
var session_ticks: int = 450
var warning_ticks: int = 15
var fed_whisperer: bool = false
var pending: Array[Dictionary] = []  # {ticker, fire_tick, log_size}
var forced: Array[Dictionary] = []   # {tick, ticker, log_size? | size_std?}


func _init(cfg: Dictionary, rng_service: RNGService, ticks: int) -> void:
	config = cfg
	rng = rng_service
	session_ticks = ticks


func reset(p_fed_whisperer: bool) -> void:
	fed_whisperer = p_fed_whisperer
	var key: String = "jump_warning_ticks_fed_whisperer" if fed_whisperer else "jump_warning_ticks"
	warning_ticks = int(config[key])
	pending.clear()


## Poisson roll for one ticker this tick. `roll` is always drawn by the caller so RNG
## consumption is identical regardless of state.
func maybe_schedule(s: StockDef, regime: String, roll: float, tick: int) -> Dictionary:
	var lam: float = float(config["regimes"][regime]["jump_lambda"])
	var rate: float = lam * float(config["jump_session_scale"]) * s.jump_rate_mult
	var p: float = 1.0 - exp(-rate / float(session_ticks))
	if roll >= p or has_pending(s.ticker) or tick + warning_ticks > session_ticks:
		return {}
	var y: float = s.jump_mean + s.jump_std * rng.rand_gaussian()
	return _schedule(s.ticker, tick + warning_ticks, y)


func _schedule(ticker: String, fire_tick: int, y: float) -> Dictionary:
	pending.append({"ticker": ticker, "fire_tick": fire_tick, "log_size": y})
	var hint: int = 0
	if fed_whisperer:
		hint = 1 if y >= 0.0 else -1
	return {"ticker": ticker, "seconds_ahead": float(warning_ticks) / float(config["ticks_per_second"]), "direction_hint": hint, "fire_tick": fire_tick}


func has_pending(ticker: String) -> bool:
	for j: Dictionary in pending:
		if str(j["ticker"]) == ticker:
			return true
	return false


func pop_due(ticker: String, tick: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for j: Dictionary in pending:
		if str(j["ticker"]) == ticker and int(j["fire_tick"]) <= tick:
			due.append(j)
	for j: Dictionary in due:
		pending.erase(j)
	return due


## Boss-forced jumps (CPI Print, Flash Crash). Each entry: {tick, ticker ("ALL" ok), log_size | size_std}.
func set_forced(list: Array[Dictionary]) -> void:
	forced = list


## Issues warnings for forced jumps whose fire tick is `warning_ticks` away; returns warning dicts.
func due_forced_warnings(tick: int, stocks: Array[StockDef]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in forced:
		var fire: int = int(f["tick"])
		if fire - warning_ticks != tick:
			continue
		for s: StockDef in stocks:
			if str(f["ticker"]) != "ALL" and str(f["ticker"]) != s.ticker:
				continue
			var y: float
			if f.has("log_size"):
				y = float(f["log_size"])
			else:
				var dir_sign: float = 1.0 if rng.randf() < 0.5 else -1.0
				y = dir_sign * float(f["size_std"]) * (1.0 + 0.5 * absf(rng.rand_gaussian()))
			out.append(_schedule(s.ticker, fire, y))
	return out
