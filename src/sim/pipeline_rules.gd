class_name PipelineRules
extends RefCounted
## Dictionary-dispatched condition and effect handlers for ModifierPipeline.
## Adding a perk = JSON only, or one new pure handler registered below (Rule 1.1 #4).

var conditions: Dictionary = {}
var effects: Dictionary = {}


func _init() -> void:
	conditions = {
		"ALWAYS": func(_c: Dictionary, _ctx: Dictionary) -> bool: return true,
		"TRADE_PROFIT_POSITIVE": func(_c: Dictionary, ctx: Dictionary) -> bool: return float(ctx.get("trade_pnl", 0.0)) > 0.0,
		"SESSION_PROFIT_POSITIVE": func(_c: Dictionary, ctx: Dictionary) -> bool: return float(ctx.get("session_profit", 0.0)) > 0.0,
		"LEVERAGE_GTE": func(c: Dictionary, ctx: Dictionary) -> bool: return int(ctx.get("leverage", 0)) >= int(c["value"]),
		"SIDE_IS": func(c: Dictionary, ctx: Dictionary) -> bool: return str(ctx.get("side", "")) == str(c["value"]),
		"ENTRY_REGIME_IS": func(c: Dictionary, ctx: Dictionary) -> bool: return str(ctx.get("entry_regime", "")) == str(c["value"]),
		"MIN_MARGIN_BELOW": func(c: Dictionary, ctx: Dictionary) -> bool: return float(ctx.get("min_margin", 1.0)) < float(c["value"]),
		"SESSION_FLOORS_GTE": func(c: Dictionary, ctx: Dictionary) -> bool: return int(ctx.get("session_floors", 0)) >= int(c["value"]),
		"STAT_GTE": func(c: Dictionary, ctx: Dictionary) -> bool: return float(ctx.get(str(c["stat"]), 0.0)) >= float(c["value"]),
		"ALL": _all,
	}
	effects = {
		"FLAT_ALPHA": func(e: Dictionary, _ctx: Dictionary, _i: PerkInstance) -> float: return float(e["amount"]),
		"DYNAMIC_FLAT_BY_STAT": func(e: Dictionary, ctx: Dictionary, _i: PerkInstance) -> float:
			var units: float = floorf(float(ctx.get(str(e["stat"]), 0.0)) / float(e.get("unit_size", 1)))
			return units * float(e["per_unit"]),
		"ADD_MULT": func(e: Dictionary, _ctx: Dictionary, _i: PerkInstance) -> float: return float(e["amount"]),
		"DYNAMIC_ADD_MULT_BY_STAT": func(e: Dictionary, ctx: Dictionary, _i: PerkInstance) -> float:
			return float(ctx.get(str(e["stat"]), 0.0)) * float(e["per_unit"]),
		"SCALING_ADD_MULT": func(_e: Dictionary, _ctx: Dictionary, i: PerkInstance) -> float: return i.counter,
		"XMULT": func(e: Dictionary, _ctx: Dictionary, _i: PerkInstance) -> float: return float(e["amount"]),
		"DYNAMIC_XMULT_BY_STAT": func(e: Dictionary, ctx: Dictionary, _i: PerkInstance) -> float:
			return float(e.get("base", 1.0)) + float(e["per_unit"]) * float(ctx.get(str(e["stat"]), 0.0)),
		"PASSIVE_ONLY": func(_e: Dictionary, _ctx: Dictionary, _i: PerkInstance) -> float: return 0.0,
	}


func check(cond: Dictionary, ctx: Dictionary) -> bool:
	var t: String = str(cond.get("type", "ALWAYS"))
	if not conditions.has(t):
		push_error("PipelineRules: unknown condition type '%s'" % t)
		return false
	return (conditions[t] as Callable).call(cond, ctx)


func value(inst: PerkInstance, ctx: Dictionary) -> float:
	var op: String = str(inst.def.effect.get("op", "PASSIVE_ONLY"))
	if not effects.has(op):
		push_error("PipelineRules: unknown effect op '%s'" % op)
		return 0.0
	return (effects[op] as Callable).call(inst.def.effect, ctx, inst)


func is_scaling(inst: PerkInstance) -> bool:
	return str(inst.def.effect.get("op", "")).begins_with("SCALING_")


func _all(c: Dictionary, ctx: Dictionary) -> bool:
	for sub: Variant in c.get("conditions", []):
		if not check(sub as Dictionary, ctx):
			return false
	return true
