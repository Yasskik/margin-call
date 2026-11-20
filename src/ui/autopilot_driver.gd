class_name AutopilotDriver
extends Node
## Dev/CI only: plays the whole loop through the real UI routing at high speed with a simple
## bot (open two longs early, close mid-session, buy the first affordable offer, continue).
## Screenshots are taken the first time each requested phase/overlay appears.

var shell: Control
var ap: DevAutopilot
var ticks_per_frame: int = 30
var snaps: Dictionary = {} # "SHOP" / "SETTLEMENT" / "AUDIT" / "BOSS" / "END" -> file name
var quit_on: String = "END" # "END" or a phase name such as "AFTER_HOURS"
var buy: bool = true
var _seen: Dictionary = {}
var _wait: float = 0.0
var _phases: Array[String] = []


func _process(delta: float) -> void:
	var router: ScreenRouter = shell.get("router")
	var run: RunController = shell.get("run")
	if router == null or run == null or router.terminal == null:
		return
	if _phases.is_empty() or _phases[_phases.size() - 1] != run.phase:
		_phases.append(run.phase)
	if _wait > 0.0:
		_wait -= delta
		return
	if router.banner.is_active():
		if _snap_once("BOSS", 0.0):
			return
		router.banner.dismiss()
		return
	match run.phase:
		"TRADING":
			if router.terminal.hold:
				return
			for i: int in ticks_per_frame:
				if run.phase != "TRADING":
					break
				_bot_tick(run)
		"SETTLEMENT":
			if router.settle.visible:
				if _snap_once("SETTLEMENT", 0.6):
					return
				router.settle.continue_pressed.emit()
		"BOSS_AUDIT":
			if router.audit.visible:
				if _snap_once("AUDIT", 1.4):
					return
				router.audit.continue_pressed.emit()
		"AFTER_HOURS":
			if _snap_once("SHOP", 1.2):
				return
			if quit_on == "AFTER_HOURS":
				_finish(run)
				return
			if buy:
				for k: int in run.shop.offers.size():
					if run.session.portfolio.cash > 2.5 * float(run.shop.offers[k]["cost"]) and not bool(run.shop.offers[k]["sold"]):
						run.buy_shop_item(k)
						break
			router.shop.next_session_pressed.emit()
			_wait = 0.1
		"GAME_OVER", "VICTORY":
			if router.ending.visible:
				if _snap_once("END", 1.0):
					return
				_finish(run)


func _bot_tick(run: RunController) -> void:
	var t: int = run.session.market.tick_idx
	if t == 20:
		run.open_position("VLTG", "LONG", 5, 0.25)
		run.open_position("OMNI", "LONG", 3, 0.25)
	elif t == 330:
		for p: PositionState in run.session.portfolio.positions.duplicate():
			run.close_position(p.id)
		_wait = 0.4
	run.advance_tick()


## Returns true when it just scheduled a snapshot (caller should yield this frame).
func _snap_once(key: String, settle_time: float) -> bool:
	if not snaps.has(key) or _seen.has(key):
		return false
	if not _seen.has(key + "_wait"):
		_seen[key + "_wait"] = true
		_wait = settle_time
		return true
	_seen[key] = true
	ap.snap(str(snaps[key]))
	if quit_on == key:
		_finish(shell.get("run"))
	return true


func _finish(run: RunController) -> void:
	print("AUTOPILOT FLOW outcome=%s phase=%s quarter=%d sessions=%d equity=%.2f" % [run.outcome, run.phase, run.quarter, int(run.stats["sessions"]), run.session.portfolio.equity()])
	print("AUTOPILOT FLOW phases=", ",".join(_phases))
	get_tree().quit(0)
