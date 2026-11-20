class_name RunController
extends RefCounted
## Stage 2 skeleton: owns one SessionRunner and exposes clean command methods to the UI.
## Stage 4A grows this into the full 12-Quarter finite state machine.

signal phase_changed(new_phase: String)
signal session_started(quarter: int, session_idx: int, boss_id: String)

var data: DataLoader
var rng: RNGService
var session: RunSession
var phase: String = "MENU"
var quarter: int = 1
var session_idx: int = 1
var seed_value: int = 0


func _init(loader: DataLoader, p_seed: int) -> void:
	data = loader
	seed_value = p_seed
	rng = RNGService.new(p_seed)


func start_run() -> void:
	var bg: Dictionary = data.get_background("bg_junior_analyst")
	session = RunSession.new(data.sim_config, data.stocks, rng.fork(1), float(bg.get("starting_cash", 10000.0)))
	session.loadout.perk_slots = int(bg.get("perk_slots", 5))
	session.loadout.algo_slots = int(bg.get("algo_slots", 4))
	for pid: Variant in bg.get("starting_perks", []):
		session.loadout.add_perk(data.get_perk(str(pid)))
	start_session()


func start_session() -> void:
	session.apply_loadout()
	session.begin()
	_set_phase("TRADING")
	session_started.emit(quarter, session_idx, "")


func advance_tick() -> void:
	if phase == "TRADING":
		session.step()


func preview_entry(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	return session.preview_entry(ticker, side, leverage, allocation_pct)


func open_position(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	return session.open_position(ticker, side, leverage, allocation_pct)


func close_position(pos_id: String) -> Dictionary:
	return session.close_position(pos_id)


## Read-only HUD snapshot for the presentation layer.
func get_hud_info() -> Dictionary:
	return {
		"quarter": quarter, "session_idx": session_idx, "sessions_per_quarter": 3, "is_boss": false,
		"boss_name": "", "boss_desc": "", "target": 0.0, "burn_rate": 0.0,
		"cash": session.portfolio.cash, "equity": session.portfolio.equity(),
		"seconds_left": session.market.seconds_left(), "regime": session.market.regime,
		"regime_drift": float(data.sim_config["regimes"][session.market.regime]["drift"]),
		"regime_odds": {}, "phase": phase,
	}


func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)
