class_name Loadout
extends RefCounted
## Owned Contacts/Perks (slot order = resolution order) and Algos, with passive-mod aggregation.

var perks: Array[PerkInstance] = []
var algos: Array[AlgoDef] = []
var perk_slots: int = 5
var algo_slots: int = 4
var disabled_perk_ids: Array[String] = []


func add_perk(d: PerkDef) -> bool:
	if d == null or has_perk(d.id) or perks.size() >= perk_slots:
		return false
	perks.append(PerkInstance.create(d))
	return true


func remove_perk(id: String) -> PerkInstance:
	for p: PerkInstance in perks:
		if p.def.id == id:
			perks.erase(p)
			return p
	return null


func has_perk(id: String) -> bool:
	return get_perk(id) != null


func get_perk(id: String) -> PerkInstance:
	for p: PerkInstance in perks:
		if p.def.id == id:
			return p
	return null


func add_algo(a: AlgoDef) -> bool:
	if a == null or has_algo(a.id) or algos.size() >= algo_slots:
		return false
	algos.append(a)
	return true


func remove_algo(id: String) -> AlgoDef:
	for a: AlgoDef in algos:
		if a.id == id:
			algos.erase(a)
			return a
	return null


func has_algo(id: String) -> bool:
	for a: AlgoDef in algos:
		if a.id == id:
			return true
	return false


func distinct_algos() -> int:
	return algos.size()


## Perks that participate this session (Boss modifiers can freeze some).
func active_perks() -> Array[PerkInstance]:
	var out: Array[PerkInstance] = []
	for p: PerkInstance in perks:
		if not disabled_perk_ids.has(p.def.id):
			out.append(p)
	return out


## All passive mods with `key` from active perks.
func mods(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: PerkInstance in active_perks():
		for m: Dictionary in p.def.passive_mods:
			if str(m.get("key", "")) == key:
				out.append(m)
	return out


func mult(key: String) -> float:
	var v: float = 1.0
	for m: Dictionary in mods(key):
		v *= float(m["value"])
	return v


func has_mod(key: String) -> bool:
	return not mods(key).is_empty()


func reset_quarter_charges() -> void:
	for p: PerkInstance in perks:
		var c: int = 0
		for m: Dictionary in p.def.passive_mods:
			c = maxi(c, int(m.get("charges_per_quarter", 0)))
		p.charges = c


func perk_defs() -> Array[PerkDef]:
	var out: Array[PerkDef] = []
	for p: PerkInstance in perks:
		out.append(p.def)
	return out
