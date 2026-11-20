class_name RunController
extends RefCounted
## 12-Quarter finite state machine (Stage 4A):
##   MENU -> TRADING -> SETTLEMENT -> AFTER_HOURS -> ... -> (Boss) TRADING -> SETTLEMENT
##   -> BOSS_AUDIT -> AFTER_HOURS (next Quarter) | VICTORY | GAME_OVER
## The UI only calls these public command methods and listens to the typed signals.

signal phase_changed(new_phase: String)
signal session_started(quarter: int, session_idx: int, boss_id: String)
signal boss_announced(boss_id: String, boss_name: String, is_fbi_raid: bool)
signal quarter_resolved(quarter: int, passed: bool, equity: float, target: float)
signal run_ended(outcome: String, summary: Dictionary)
signal settlement_ready(summary: Dictionary)
signal shop_changed

const SESSIONS_PER_QUARTER: int = 3
const LAST_QUARTER: int = 12

var data: DataLoader
var rng: RNGService
var shop_rng: RNGService
var boss_rng: RNGService
var session: RunSession
var life: LifeSimState
var shop: ShopGenerator
var rules: QuarterRules
var phase: String = "MENU"
var quarter: int = 1
var session_idx: int = 1
var seed_value: int = 0
var background: Dictionary = {}
var quarter_gains: float = 0.0
var boss_fx: Dictionary = {}
var last_settlement: Dictionary = {}
var last_audit: Dictionary = {}
var stats: Dictionary = {"peak_equity": 0.0, "taxes_paid": 0.0, "burn_paid": 0.0, "walls": 0, "best_combo": 0.0, "sessions": 0}
var outcome: String = ""


func _init(loader: DataLoader, p_seed: int) -> void:
	data = loader
	seed_value = p_seed
	rng = RNGService.new(p_seed)
	shop_rng = rng.fork(2)
	boss_rng = rng.fork(3)
	rules = QuarterRules.new(loader.sim_config, loader.bosses)


func start_run(background_id: String = "bg_junior_analyst") -> void:
	background = data.get_background(background_id)
	var econ: Dictionary = data.sim_config.get("economy", {})
	life = LifeSimState.new(econ, data.lifestyle_upgrades)
	life.burn_rate_mult = float(background.get("burn_rate_mult", 1.0))
	life.add_prestige(float(background.get("starting_prestige", 0)))
	session = RunSession.new(data.sim_config, data.stocks, rng.fork(1), float(background.get("starting_cash", 10000.0)))
	session.loadout.perk_slots = int(background.get("perk_slots", 5))
	session.loadout.algo_slots = int(background.get("algo_slots", 4))
	for pid: Variant in background.get("starting_perks", []):
		session.loadout.add_perk(data.get_perk(str(pid)))
	session.session_finished.connect(_on_session_finished)
	session.margin_called.connect(_on_margin_called)
	shop = ShopGenerator.new(econ, data.perks, data.algos, data.sim_config.get("features", {}), shop_rng)
	quarter = 1
	session_idx = 1
	stats["peak_equity"] = session.portfolio.equity()
	start_session()


## --- Trading ---------------------------------------------------------------------------

func is_boss_session() -> bool:
	return session_idx > SESSIONS_PER_QUARTER


func current_boss() -> Dictionary:
	return rules.boss_for(quarter)


func start_session() -> void:
	rules.clear_boss(session)
	boss_fx = {}
	var boss: Dictionary = current_boss()
	if is_boss_session():
		boss_fx = rules.apply_boss(session, rules.resolve_modifiers(boss, boss_rng), boss_rng)
	_sync_life()
	session.apply_loadout()
	session.begin()
	_set_phase("TRADING")
	session_started.emit(quarter, session_idx, str(boss["id"]) if is_boss_session() else "")


func advance_tick() -> void:
	if phase == "TRADING":
		session.step()


func preview_entry(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	return session.preview_entry(ticker, side, leverage, allocation_pct)


func open_position(ticker: String, side: String, leverage: int, allocation_pct: float) -> Dictionary:
	if phase != "TRADING":
		return {"ok": false, "reason": "Market closed"}
	return session.open_position(ticker, side, leverage, allocation_pct)


func close_position(pos_id: String) -> Dictionary:
	if phase != "TRADING":
		return {"ok": false}
	return session.close_position(pos_id)


func _on_margin_called(final_equity: float) -> void:
	if final_equity <= 0.0:
		session.active = false
		_end_run("MARGIN_CALL")


func _on_session_finished(summary: Dictionary) -> void:
	if phase == "GAME_OVER":
		return
	quarter_gains += float(summary["session_realized"])
	stats["sessions"] = int(stats["sessions"]) + 1
	stats["walls"] = int(stats["walls"]) + int(summary["walls"]) + int(summary["floors"])
	stats["best_combo"] = maxf(float(stats["best_combo"]), float(summary["best_combo"]))
	stats["peak_equity"] = maxf(float(stats["peak_equity"]), float(summary["equity"]))
	summary["quarter"] = quarter
	summary["session_idx"] = session_idx
	summary["is_boss"] = is_boss_session()
	summary["target"] = float(current_boss()["target_equity"])
	summary["quarter_gains"] = quarter_gains
	last_settlement = summary
	_set_phase("SETTLEMENT")
	settlement_ready.emit(summary)


## --- Settlement / Audit ----------------------------------------------------------------

func continue_from_settlement() -> void:
	if phase != "SETTLEMENT":
		return
	if is_boss_session():
		_resolve_audit()
	else:
		_open_after_hours()


func _resolve_audit() -> void:
	var boss: Dictionary = current_boss()
	var burn: float = life.burn_rate(float(boss["burn_rate"]))
	var tax: float = rules.capital_gains_tax(quarter_gains, float(boss_fx.get("tax_rate_add", 0.0)))
	last_audit = rules.audit(session.portfolio.equity(), float(boss["target_equity"]), burn, tax)
	last_audit["quarter"] = quarter
	last_audit["boss_name"] = str(boss["name"])
	if bool(last_audit["passed"]):
		session.portfolio.cash -= burn + tax
		stats["taxes_paid"] = float(stats["taxes_paid"]) + tax
		stats["burn_paid"] = float(stats["burn_paid"]) + burn
	_set_phase("BOSS_AUDIT")
	quarter_resolved.emit(quarter, bool(last_audit["passed"]), float(last_audit["net"]), float(last_audit["target"]))


func continue_from_audit() -> void:
	if phase != "BOSS_AUDIT":
		return
	if not bool(last_audit["passed"]):
		_end_run("INSOLVENCY")
		return
	if quarter >= LAST_QUARTER:
		_end_run("VICTORY")
		return
	life.add_prestige(float(data.sim_config.get("economy", {}).get("prestige_per_quarter_cleared", 0)))
	quarter += 1
	session_idx = 0
	quarter_gains = 0.0
	session.loadout.reset_quarter_charges()
	_open_after_hours()


## --- After-Hours shop ------------------------------------------------------------------

func _open_after_hours() -> void:
	rules.clear_boss(session)
	shop.open_visit(quarter, life.prestige, life.shop_tier(), owned_ids())
	_set_phase("AFTER_HOURS")
	shop_changed.emit()


func next_session() -> void:
	if phase != "AFTER_HOURS":
		return
	session_idx += 1
	if is_boss_session():
		var boss: Dictionary = current_boss()
		boss_announced.emit(str(boss["id"]), str(boss["name"]), false)
	start_session()


func owned_ids() -> Array[String]:
	return RunShopService.owned_ids(self)


func buy_shop_item(idx: int) -> Dictionary:
	return RunShopService.buy(self, idx)


func sell_perk(perk_id: String) -> Dictionary:
	return RunShopService.sell(self, perk_id)


func reroll_shop() -> Dictionary:
	return RunShopService.reroll(self)


func toggle_lock(idx: int) -> bool:
	var locked: bool = shop.toggle_lock(idx)
	shop_changed.emit()
	return locked


## --- Helpers ---------------------------------------------------------------------------

func _sync_life() -> void:
	session.life_stats = life.stats_dict()
	session.portfolio.allow_10x = bool(background.get("unlock_10x", false)) or life.prestige >= float(data.sim_config.get("leverage_10x_min_prestige", 25))


func _end_run(result: String) -> void:
	outcome = result
	stats["final_equity"] = session.portfolio.equity()
	stats["quarter"] = quarter
	stats["seed"] = seed_value
	_set_phase("VICTORY" if result == "VICTORY" else "GAME_OVER")
	run_ended.emit(result, stats.duplicate())


func get_hud_info() -> Dictionary:
	return RunHud.build(self)


func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)
