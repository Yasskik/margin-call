class_name ModifierPipeline
extends RefCounted
## Ordered 4-phase Balatro resolver (Part 2.4):
##   FinalPayout = (BaseAlpha + sum FlatAlpha) x (1 + sum AdditiveMult) x prod CompoundXMult
## Emits an ordered Array[TriggerStep] for playback. Negative subtotals are never multiplied up.

const PHASES: Array[String] = ["BASE_ALPHA", "FLAT_ALPHA", "ADDITIVE_MULT", "COMPOUND_XMULT"]
const PHASE_HEX: Dictionary = {
	"BASE_ALPHA": "#00E676", "FLAT_ALPHA": "#38BDF8", "ADDITIVE_MULT": "#D4AF37", "COMPOUND_XMULT": "#FF3B5C",
}

var rules: PipelineRules = PipelineRules.new()


## base_items: [{source_id, label, value}] (Phase 1)
## game_mods: base-game contributions [{source_id, label, phase, value}] resolved before perks
## perks: owned instances in slot order (left-to-right)
func evaluate(hook: String, ctx: Dictionary, perks: Array[PerkInstance], base_items: Array[Dictionary], game_mods: Array[Dictionary] = []) -> Dictionary:
	var steps: Array[TriggerStep] = []
	var base: float = 0.0
	for b: Dictionary in base_items:
		base += float(b["value"])
		steps.append(_step(str(b["source_id"]), str(b["label"]), "BASE_ALPHA", float(b["value"]), base))
	var contrib: Dictionary = {"FLAT_ALPHA": [], "ADDITIVE_MULT": [], "COMPOUND_XMULT": []}
	for g: Dictionary in game_mods:
		(contrib[str(g["phase"])] as Array).append(g)
	for inst: PerkInstance in perks:
		var d: PerkDef = inst.def
		if not contrib.has(d.phase):
			continue
		var fires: bool = d.trigger_hook == hook or (rules.is_scaling(inst) and hook == "ON_TRADE_CLOSE")
		if not fires or not rules.check(d.condition, ctx):
			continue
		var v: float = rules.value(inst, ctx)
		if _is_noop(d.phase, v):
			continue
		(contrib[d.phase] as Array).append({"source_id": d.id, "label": d.name, "phase": d.phase, "value": v})
	var subtotal: float = base
	for c: Dictionary in contrib["FLAT_ALPHA"]:
		subtotal += float(c["value"])
		steps.append(_step(str(c["source_id"]), str(c["label"]), "FLAT_ALPHA", float(c["value"]), subtotal))
	var protected: bool = subtotal <= 0.0
	var add_total: float = 0.0
	var x_total: float = 1.0
	if not protected:
		for c: Dictionary in contrib["ADDITIVE_MULT"]:
			add_total += float(c["value"])
			steps.append(_step(str(c["source_id"]), str(c["label"]), "ADDITIVE_MULT", float(c["value"]), subtotal * (1.0 + add_total)))
		for c: Dictionary in contrib["COMPOUND_XMULT"]:
			x_total *= float(c["value"])
			steps.append(_step(str(c["source_id"]), str(c["label"]), "COMPOUND_XMULT", float(c["value"]), subtotal * (1.0 + add_total) * x_total))
	var payout: float = subtotal * (1.0 + add_total) * x_total
	for i: int in steps.size():
		steps[i].pitch_step = i
	return {
		"payout": payout, "steps": steps, "base": base, "flat": subtotal - base,
		"add_mult": 1.0 + add_total, "x_mult": x_total, "loss_protected": protected,
	}


## Advances SCALING_* perks whose trigger hook just happened (e.g. Tape Reader on ON_WALL_SMASH).
func notify(hook: String, ctx: Dictionary, perks: Array[PerkInstance]) -> Array[PerkInstance]:
	var bumped: Array[PerkInstance] = []
	for inst: PerkInstance in perks:
		if inst.def.trigger_hook != hook or not rules.is_scaling(inst):
			continue
		if rules.check(inst.def.condition, ctx):
			inst.counter += float(inst.def.effect.get("increment", 0.0))
			bumped.append(inst)
	return bumped


func _is_noop(phase: String, v: float) -> bool:
	if phase == "COMPOUND_XMULT":
		return is_equal_approx(v, 1.0)
	return is_zero_approx(v)


func _step(src: String, label: String, phase: String, v: float, running: float) -> TriggerStep:
	var t: TriggerStep = TriggerStep.make(src, label, phase, v, str(PHASE_HEX[phase]))
	t.running_total = running
	return t

