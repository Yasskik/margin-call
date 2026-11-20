class_name StockDef
extends RefCounted
## Typed launch ticker definition (data/stocks.json).

const REQUIRED_KEYS: Array[String] = [
	"ticker", "name", "sector", "start_price", "base_drift", "base_volatility",
	"spread_pct", "borrow_rate_annual", "jump_rate_mult", "regime_beta",
	"jump_mean", "jump_std", "wall_offsets_pct",
]

var ticker: String = ""
var name: String = ""
var sector: String = ""
var start_price: float = 100.0
var base_drift: float = 0.0
var base_volatility: float = 0.2
var spread_pct: float = 0.001
var borrow_rate_annual: float = 0.01
var jump_rate_mult: float = 1.0
var regime_beta: float = 1.0
var jump_mean: float = 0.0
var jump_std: float = 0.05
var dividend_yield_annual: float = 0.0
var stress_mult: float = 1.0
var wall_offsets_pct: Array[float] = []
var role: String = ""


static func from_dict(d: Dictionary) -> StockDef:
	var s: StockDef = StockDef.new()
	s.ticker = str(d.get("ticker", ""))
	s.name = str(d.get("name", ""))
	s.sector = str(d.get("sector", ""))
	s.start_price = float(d.get("start_price", 100.0))
	s.base_drift = float(d.get("base_drift", 0.0))
	s.base_volatility = float(d.get("base_volatility", 0.2))
	s.spread_pct = float(d.get("spread_pct", 0.001))
	s.borrow_rate_annual = float(d.get("borrow_rate_annual", 0.01))
	s.jump_rate_mult = float(d.get("jump_rate_mult", 1.0))
	s.regime_beta = float(d.get("regime_beta", 1.0))
	s.jump_mean = float(d.get("jump_mean", 0.0))
	s.jump_std = float(d.get("jump_std", 0.05))
	s.dividend_yield_annual = float(d.get("dividend_yield_annual", 0.0))
	s.stress_mult = float(d.get("stress_mult", 1.0))
	s.role = str(d.get("role", ""))
	var offs: Array = d.get("wall_offsets_pct", [])
	for o: Variant in offs:
		s.wall_offsets_pct.append(float(o))
	return s
