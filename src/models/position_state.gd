class_name PositionState
extends RefCounted
## One open leveraged position. Pure data; math lives in PortfolioState.

var id: String = ""
var ticker: String = ""
var side: String = "LONG" # "LONG" | "SHORT"
var leverage: int = 1
var collateral: float = 0.0
var notional: float = 0.0
var entry_price: float = 0.0
var entry_mid: float = 0.0
var entry_regime: String = "CALM"
var opened_tick: int = 0
var borrow_paid: float = 0.0
var dividends: float = 0.0
var unrealized_pnl: float = 0.0
var peak_pnl: float = 0.0
var wall_tier: int = 0
var wall_bonus: float = 0.0
var walls_smashed: int = 0
var ticks_in_profit: int = 0


func is_long() -> bool:
	return side == "LONG"


func direction() -> float:
	return 1.0 if side == "LONG" else -1.0


func to_dict() -> Dictionary:
	return {
		"id": id, "ticker": ticker, "side": side, "leverage": leverage,
		"collateral": collateral, "notional": notional, "entry_price": entry_price,
		"entry_regime": entry_regime, "opened_tick": opened_tick, "borrow_paid": borrow_paid,
		"unrealized_pnl": unrealized_pnl, "wall_tier": wall_tier, "wall_bonus": wall_bonus,
	}
