class_name ScreenRouter
extends Node
## Phase router (Stage 4A): listens to EventBus.phase_changed / session_started / run_ended and
## swaps Title -> Terminal (+ Boss banner, Settlement, Audit overlays) -> After-Hours -> Receipt.

signal new_run_requested

var host: Control
var sequencer: ComboSequencer
var run: RunController
var terminal: MainTerminal
var shop: AfterHoursShop
var title: TitleScreen
var settle: SettlementOverlay
var audit: AuditOverlay
var ending: RunEndScreen
var banner: BossIntroBanner
var _overlay_layer: Control
var _token: int = 0


func setup(screen_host: Control, overlay_layer: Control, seq: ComboSequencer) -> void:
	host = screen_host
	_overlay_layer = overlay_layer
	sequencer = seq
	title = TitleScreen.new()
	title.build()
	title.start_pressed.connect(func() -> void: new_run_requested.emit())
	settle = SettlementOverlay.new()
	settle.continue_pressed.connect(func() -> void:
		settle.visible = false
		run.continue_from_settlement())
	audit = AuditOverlay.new()
	audit.continue_pressed.connect(func() -> void:
		audit.visible = false
		run.continue_from_audit())
	ending = RunEndScreen.new()
	ending.new_run_pressed.connect(func() -> void: new_run_requested.emit())
	banner = BossIntroBanner.new()
	banner.dismissed.connect(func() -> void:
		if terminal != null:
			terminal.hold = false)
	for c: Control in [banner, settle, audit, ending, title]:
		c.visible = false
		_overlay_layer.add_child(c)
	EventBus.phase_changed.connect(_on_phase)
	EventBus.session_started.connect(_on_session_started)


func show_menu() -> void:
	_hide_overlays()
	title.visible = true


## Called by RootShell after a fresh RunController exists but before start_run().
func attach_run(r: RunController) -> void:
	run = r
	_token += 1
	if terminal != null:
		terminal.queue_free()
	if shop != null:
		shop.queue_free()
	terminal = MainTerminal.new()
	host.add_child(terminal)
	terminal.build(run)
	shop = AfterHoursShop.new()
	host.add_child(shop)
	shop.build(run)
	shop.visible = false
	shop.next_session_pressed.connect(func() -> void: run.next_session())
	sequencer.tray = terminal.tray
	_hide_overlays()


func _hide_overlays() -> void:
	for c: Control in [banner, settle, audit, ending, title]:
		c.visible = false


func _refresh_tray() -> void:
	var lo: Loadout = run.session.loadout
	terminal.tray.show_perks(lo.perk_defs(), lo.perk_slots, lo.disabled_perk_ids)


func _on_session_started(_q: int, _s: int, boss_id: String) -> void:
	if run == null or terminal == null:
		return
	terminal.bind_session(run.session)
	terminal.trade.on_session_started()
	_refresh_tray()
	if boss_id != "":
		terminal.hold = true
		var info: Dictionary = run.get_hud_info()
		banner.announce(run.current_boss(), float(info["target"]), float(info["burn_rate"]))


func _on_phase(p: String) -> void:
	if run == null:
		return
	var token: int = _token
	match p:
		"TRADING":
			_hide_overlays()
			shop.visible = false
			terminal.visible = true
		"SETTLEMENT":
			var steps: Array = run.last_settlement.get("settlement_steps", [])
			if not steps.is_empty():
				var pnl: float = float(run.last_settlement["session_realized"])
				sequencer.enqueue(steps, pnl, "SESSION SETTLEMENT · CONTACTS PAY OUT")
			await _wait_sequencer(0.5)
			if token == _token and run.phase == "SETTLEMENT":
				settle.show_summary(run, run.last_settlement)
				settle.visible = true
		"BOSS_AUDIT":
			audit.show_audit(run.last_audit, run.rules.tax_rate(float(run.boss_fx.get("tax_rate_add", 0.0))))
			audit.visible = true
		"AFTER_HOURS":
			_hide_overlays()
			terminal.visible = false
			shop.visible = true
			shop.refresh()
		"GAME_OVER", "VICTORY":
			await _wait_sequencer(1.2)
			if token == _token and (run.phase == "GAME_OVER" or run.phase == "VICTORY"):
				_hide_overlays()
				var st: Dictionary = run.stats.duplicate()
				ending.show_end(run.outcome, st)
				ending.visible = true


func _wait_sequencer(extra: float) -> void:
	await get_tree().create_timer(0.15).timeout
	while sequencer.is_busy():
		await get_tree().process_frame
	await get_tree().create_timer(extra).timeout
