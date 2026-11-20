class_name AutopilotScenarios
extends RefCounted
## Scripted input timelines for DevAutopilot (screenshots / smoke tests only).


static func build(scenario: String) -> Array[Dictionary]:
	var s: Array[Dictionary] = []
	match scenario:
		"terminal":
			s.append({"at": 1.0, "do": "select", "ticker": "VLTG"})
			s.append({"at": 1.2, "do": "open", "side": "LONG", "lev": 5, "alloc": 0.5})
			s.append({"at": 1.4, "do": "select", "ticker": "OMNI"})
			s.append({"at": 1.6, "do": "open", "side": "LONG", "lev": 3, "alloc": 0.25})
			s.append({"at": 8.8, "do": "dump"})
			s.append({"at": 9.0, "do": "snap", "name": "terminal"})
			s.append({"at": 9.5, "do": "quit"})
		"combo":
			s.append({"at": 0.5, "do": "grant", "perks": ["perk_margin_cowboy", "perk_tape_reader", "perk_hft_arbitrage", "perk_knife_catcher"]})
			s.append({"at": 0.8, "do": "select", "ticker": "VLTG"})
			s.append({"at": 1.0, "do": "open", "side": "LONG", "lev": 5, "alloc": 0.5})
			s.append({"at": 1.2, "do": "select", "ticker": "OMNI"})
			s.append({"at": 1.4, "do": "open", "side": "LONG", "lev": 5, "alloc": 0.25})
			s.append({"at": 14.0, "do": "close_all"})
			s.append({"at": 14.75, "do": "snap", "name": "combo"})
			s.append({"at": 15.5, "do": "quit"})
		_:
			s.append({"at": 3.0, "do": "snap", "name": "boot"})
			s.append({"at": 3.5, "do": "quit"})
	return s


static func run_step(ap: DevAutopilot, step: Dictionary) -> void:
	var shell: Control = ap.shell
	var what: String = str(step["do"])
	var term: MainTerminal = shell.get("terminal") as MainTerminal
	match what:
		"select":
			term.tickers.select(str(step["ticker"]))
		"open":
			term.trade.set_leverage(int(step["lev"]))
			term.trade.set_allocation(float(step["alloc"]))
			term.trade.open_side(str(step["side"]))
		"close_all":
			for p: PositionState in term.run.session.portfolio.positions.duplicate():
				term.run.close_position(p.id)
		"snap":
			ap.snap(str(step["name"]))
		"grant":
			for pid: Variant in step["perks"]:
				term.run.session.loadout.add_perk(DataRegistry.loader.get_perk(str(pid)))
			term.run.session.apply_loadout()
			term.tray.show_perks(term.run.session.loadout.perk_defs(), term.run.session.loadout.perk_slots)
		"dump":
			_dump(term, 0)
		"quit":
			ap.get_tree().quit(0)
		_:
			if shell.has_method("autopilot_" + what):
				shell.call("autopilot_" + what, step)


static func _dump(n: Node, depth: int) -> void:
	if depth > 4:
		return
	if n is Control:
		var c: Control = n
		print("%s%s size=%s min=%s" % ["  ".repeat(depth), c.get_class(), str(c.size), str(c.get_combined_minimum_size())])
	for ch: Node in n.get_children():
		_dump(ch, depth + 1)
