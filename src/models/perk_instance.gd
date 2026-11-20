class_name PerkInstance
extends RefCounted
## Owned copy of a PerkDef with its run-time state (scaling counter, per-Quarter charges).

var def: PerkDef
var counter: float = 0.0
var charges: int = 0


static func create(d: PerkDef) -> PerkInstance:
	var p: PerkInstance = PerkInstance.new()
	p.def = d
	p.counter = float(d.effect.get("initial", 0.0))
	p.charges = 0
	for m: Dictionary in d.passive_mods:
		p.charges = maxi(p.charges, int(m.get("charges_per_quarter", 0)))
	return p


func to_dict() -> Dictionary:
	return {"id": def.id, "counter": counter, "charges": charges}
