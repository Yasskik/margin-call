class_name TriggerStep
extends RefCounted
## One ordered step of a Balatro-style 4-phase resolution, replayed by ComboSequencer.

var source_id: String = ""
var label: String = ""
var phase: String = "BASE_ALPHA" # BASE_ALPHA | FLAT_ALPHA | ADDITIVE_MULT | COMPOUND_XMULT
var value: float = 0.0
var color_hex: String = "#00E676"
var running_total: float = 0.0
var pitch_step: int = 0


static func make(src: String, txt: String, ph: String, val: float, col: String) -> TriggerStep:
	var t: TriggerStep = TriggerStep.new()
	t.source_id = src
	t.label = txt
	t.phase = ph
	t.value = val
	t.color_hex = col
	return t


func to_dict() -> Dictionary:
	return {
		"source_id": source_id, "label": label, "phase": phase, "value": value,
		"color_hex": color_hex, "running_total": running_total, "pitch_step": pitch_step,
	}
