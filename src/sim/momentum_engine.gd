class_name MomentumEngine
extends RefCounted
## Kinetic Momentum K_t in [0, 100] (trailing 10-tick aligned profit velocity) and per-position
## Resistance Wall / Support Floor ladders with WallBonus_k = 0.05 * N * k * (1 + K/100) (Part 2.4).

var window_ticks: int = 10
var full_scale_return: float = 0.02
var smoothing: float = 0.25
var wall_bonus_base: float = 0.05
var min_leverage: int = 2
var momentum: float = 0.0
var short_gain_mult: float = 1.0   # Bear Raid Syndicate
var gain_mult: float = 1.0         # Momentum Nitro (Stage 5)
var wall_bonus_mult: float = 1.0   # Bloomberg Trial
var wall_distance_mult: float = 1.0 # Spoof the Order Book (Stage 4B)
var session_wall_tier: int = 0
var session_walls_broken: int = 0
var session_floors_broken: int = 0
var run_walls_broken: int = 0
var _ladders: Dictionary = {} # pos_id -> {"prices": Array[float], "next": int, "side": String}


func _init(momentum_cfg: Dictionary) -> void:
	window_ticks = int(momentum_cfg.get("window_ticks", 10))
	full_scale_return = float(momentum_cfg.get("full_scale_return", 0.02))
	smoothing = float(momentum_cfg.get("smoothing", 0.25))
	wall_bonus_base = float(momentum_cfg.get("wall_bonus_base", 0.05))
	min_leverage = int(momentum_cfg.get("wall_smash_min_leverage", 2))


func reset_session() -> void:
	momentum = 0.0
	session_wall_tier = 0
	session_walls_broken = 0
	session_floors_broken = 0
	_ladders.clear()


## Builds the wall ladder above (Long) or below (Short) the entry mid. 1x positions get none.
func register_position(p: PositionState, offsets: Array[float]) -> void:
	if p.leverage < min_leverage:
		return
	var prices: Array[float] = []
	for o: float in offsets:
		var off: float = o * wall_distance_mult
		prices.append(p.entry_mid * (1.0 + off) if p.is_long() else p.entry_mid * (1.0 - off))
	_ladders[p.id] = {"prices": prices, "next": 0, "side": p.side}


func unregister(pos_id: String) -> void:
	_ladders.erase(pos_id)


func get_ladder(pos_id: String) -> Dictionary:
	return _ladders.get(pos_id, {})


func has_ladder(pos_id: String) -> bool:
	return _ladders.has(pos_id)


## Aligned trailing return for one position from the session mid history.
func aligned_return(p: PositionState, hist: Array) -> float:
	if hist.size() < 2:
		return 0.0
	var last: int = hist.size() - 1
	var back: int = maxi(0, last - window_ticks)
	return p.direction() * (float(hist[last]) / float(hist[back]) - 1.0)


## Updates K_t from all open positions (notional-weighted) and returns wall-smash events.
func update(positions: Array[PositionState], histories: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var weighted: float = 0.0
	var total_n: float = 0.0
	for p: PositionState in positions:
		var hist: Array = histories.get(p.ticker, [])
		var r: float = aligned_return(p, hist)
		if not p.is_long():
			r *= short_gain_mult
		weighted += r * p.notional
		total_n += p.notional
		if hist.size() > 0:
			events.append_array(check_walls(p, float(hist[hist.size() - 1])))
	var target: float = 0.0
	if total_n > 0.0:
		target = clampf(100.0 * (weighted / total_n) * gain_mult / full_scale_return, 0.0, 100.0)
	momentum = clampf(momentum + (target - momentum) * smoothing, 0.0, 100.0)
	return events


## Detects every wall crossed this tick (can be several on a jump) and advances the tier.
func check_walls(p: PositionState, price: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _ladders.has(p.id):
		return events
	var lad: Dictionary = _ladders[p.id]
	var prices: Array[float] = lad["prices"]
	var nxt: int = int(lad["next"])
	while nxt < prices.size():
		var wall: float = prices[nxt]
		var crossed: bool = price >= wall if p.is_long() else price <= wall
		if not crossed:
			break
		var tier: int = nxt + 1
		var bonus: float = wall_bonus(p.notional, tier)
		p.wall_tier = tier
		p.wall_bonus += bonus
		p.walls_smashed += 1
		session_wall_tier += 1
		run_walls_broken += 1
		if p.is_long():
			session_walls_broken += 1
		else:
			session_floors_broken += 1
		events.append({"pos_id": p.id, "ticker": p.ticker, "side": p.side, "tier": tier, "wall_price": wall, "bonus": bonus, "momentum": momentum})
		nxt += 1
	lad["next"] = nxt
	return events


func wall_bonus(notional: float, tier: int) -> float:
	return wall_bonus_base * notional * float(tier) * (1.0 + momentum / 100.0) * wall_bonus_mult


func reset_momentum() -> void:
	momentum = 0.0
