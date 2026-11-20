class_name DataLoader
extends RefCounted
## Pure RefCounted JSON loader/validator (Rule 1.1 #7). No autoloads, no Nodes.
## Every missing/malformed key is reported via push_error() and collected in `errors`.

const REGIME_NAMES: Array[String] = ["CALM", "BULL_MANIA", "VOLATILE", "CRASH"]
const SIM_REQUIRED: Array[String] = [
	"ticks_per_second", "session_seconds", "session_sim_days", "trading_days_per_year",
	"drift_game_scale", "regime_check_interval_ticks", "regime_start_weights", "regimes",
	"regime_transitions", "jump_session_scale", "jump_warning_ticks",
	"jump_warning_ticks_fed_whisperer", "margin_safe", "margin_liquidation",
	"forced_liquidation_slippage", "enable_sleep_burnout",
]
const BOSS_REQUIRED: Array[String] = ["quarter", "id", "name", "description", "target_equity", "burn_rate", "modifiers"]

var errors: PackedStringArray = PackedStringArray()
var sim_config: Dictionary = {}
var stocks: Array[StockDef] = []
var perks: Array[PerkDef] = []
var algos: Array[AlgoDef] = []
var bosses: Array[Dictionary] = []
var lifestyle_upgrades: Array[Dictionary] = []
var shady_deals: Array[Dictionary] = []
var backgrounds: Array[Dictionary] = []


func load_all(base_path: String) -> bool:
	errors.clear()
	sim_config = _read_json(base_path.path_join("sim_config.json"))
	validate_sim_config(sim_config)
	_load_stocks(_read_json(base_path.path_join("stocks.json")))
	_load_perks(_read_json(base_path.path_join("contacts_perks.json")))
	_load_algos(_read_json(base_path.path_join("algos_strategies.json")))
	bosses = _load_dict_list(_read_json(base_path.path_join("quarterly_bosses.json")), "bosses", BOSS_REQUIRED)
	bosses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["quarter"]) < int(b["quarter"]))
	lifestyle_upgrades = _load_dict_list(_read_json(base_path.path_join("lifestyle_upgrades.json")), "upgrades", ["id", "track", "tier", "name", "cost", "burn_rate_add", "prestige"])
	shady_deals = _load_dict_list(_read_json(base_path.path_join("shady_deals.json")), "deals", ["id", "name", "cost", "sec_heat_delta", "stress_delta", "duration_sessions", "description", "modifier_key", "modifier_value"])
	backgrounds = _load_dict_list(_read_json(base_path.path_join("backgrounds.json")), "backgrounds", ["id", "name", "starting_cash", "algo_slots", "perk_slots", "starting_perks"])
	return is_valid()


func is_valid() -> bool:
	return errors.is_empty()


func counts() -> Dictionary:
	return {
		"stocks": stocks.size(), "perks": perks.size(), "algos": algos.size(),
		"bosses": bosses.size(), "lifestyle_upgrades": lifestyle_upgrades.size(),
		"shady_deals": shady_deals.size(), "backgrounds": backgrounds.size(),
		"sim_config_keys": sim_config.size(),
	}


## Validates the [v1.1] sim contract: required keys, row sums and start weights == 1.0 +/- 0.001.
func validate_sim_config(cfg: Dictionary) -> bool:
	var ok: bool = true
	for key: String in SIM_REQUIRED:
		if not cfg.has(key):
			ok = _fail("sim_config.json: missing key '%s'" % key)
	if not ok:
		return false
	var weights: Dictionary = cfg["regime_start_weights"]
	if absf(_sum_values(weights) - 1.0) > 0.001:
		ok = _fail("sim_config.json: regime_start_weights sum to %.4f, expected 1.0" % _sum_values(weights))
	var regimes: Dictionary = cfg["regimes"]
	var trans: Dictionary = cfg["regime_transitions"]
	for r: String in REGIME_NAMES:
		if not regimes.has(r):
			ok = _fail("sim_config.json: regimes missing '%s'" % r)
		elif not (regimes[r] as Dictionary).has_all(["drift", "vol_mult", "jump_lambda"]):
			ok = _fail("sim_config.json: regime '%s' needs drift, vol_mult, jump_lambda" % r)
		if not trans.has(r):
			ok = _fail("sim_config.json: regime_transitions missing row '%s'" % r)
			continue
		var row_sum: float = _sum_values(trans[r])
		if absf(row_sum - 1.0) > 0.001:
			ok = _fail("sim_config.json: regime_transitions row '%s' sums to %.4f, expected 1.0" % [r, row_sum])
	return ok


func get_stock(ticker: String) -> StockDef:
	for s: StockDef in stocks:
		if s.ticker == ticker:
			return s
	return null


func get_perk(id: String) -> PerkDef:
	for p: PerkDef in perks:
		if p.id == id:
			return p
	return null


func get_algo(id: String) -> AlgoDef:
	for a: AlgoDef in algos:
		if a.id == id:
			return a
	return null


func get_boss_for_quarter(quarter: int) -> Dictionary:
	for b: Dictionary in bosses:
		if int(b["quarter"]) == quarter:
			return b
	return {}


func get_background(id: String) -> Dictionary:
	for b: Dictionary in backgrounds:
		if str(b["id"]) == id:
			return b
	return {}


func _load_stocks(root: Dictionary) -> void:
	stocks.clear()
	for d: Dictionary in _load_dict_list(root, "stocks", StockDef.REQUIRED_KEYS):
		var s: StockDef = StockDef.from_dict(d)
		if s.wall_offsets_pct.is_empty():
			_fail("stocks.json: %s has empty wall_offsets_pct" % s.ticker)
		if s.base_volatility <= 0.0 or s.start_price <= 0.0:
			_fail("stocks.json: %s needs positive start_price and base_volatility" % s.ticker)
		stocks.append(s)


func _load_perks(root: Dictionary) -> void:
	perks.clear()
	for d: Dictionary in _load_dict_list(root, "perks", PerkDef.REQUIRED_KEYS):
		var p: PerkDef = PerkDef.from_dict(d)
		if not PerkDef.VALID_PHASES.has(p.phase):
			_fail("contacts_perks.json: %s has invalid phase '%s'" % [p.id, p.phase])
		if not PerkDef.VALID_HOOKS.has(p.trigger_hook):
			_fail("contacts_perks.json: %s has invalid trigger_hook '%s'" % [p.id, p.trigger_hook])
		if not PerkDef.VALID_RARITIES.has(p.rarity):
			_fail("contacts_perks.json: %s has invalid rarity '%s'" % [p.id, p.rarity])
		if not p.effect.has("op") or not p.condition.has("type"):
			_fail("contacts_perks.json: %s needs effect.op and condition.type" % p.id)
		perks.append(p)


func _load_algos(root: Dictionary) -> void:
	algos.clear()
	for d: Dictionary in _load_dict_list(root, "algos", AlgoDef.REQUIRED_KEYS):
		algos.append(AlgoDef.from_dict(d))


func _load_dict_list(root: Dictionary, list_key: String, required: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if root.is_empty():
		return out
	if not root.has(list_key) or not (root[list_key] is Array):
		_fail("JSON root missing array '%s'" % list_key)
		return out
	var idx: int = 0
	for item: Variant in root[list_key]:
		if not (item is Dictionary):
			_fail("%s[%d] is not an object" % [list_key, idx])
		else:
			var d: Dictionary = item
			var missing: Array[String] = []
			for key: String in required:
				if not d.has(key):
					missing.append(key)
			if missing.is_empty():
				out.append(d)
			else:
				_fail("%s[%d] (%s) missing keys: %s" % [list_key, idx, str(d.get("id", d.get("ticker", "?"))), ", ".join(missing)])
		idx += 1
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing data file %s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		_fail("%s: JSON parse error line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		_fail("%s: root must be an object" % path)
		return {}
	var d: Dictionary = json.data
	if int(d.get("schema_version", 0)) != 1:
		_fail("%s: unsupported schema_version %s" % [path, str(d.get("schema_version"))])
	return d


func _sum_values(d: Dictionary) -> float:
	var total: float = 0.0
	for v: Variant in d.values():
		total += float(v)
	return total


func _fail(msg: String) -> bool:
	errors.append(msg)
	push_error("DataLoader: " + msg)
	return false
