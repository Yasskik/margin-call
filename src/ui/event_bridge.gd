class_name EventBridge
extends Node
## Forwards typed sim signals (RefCounted) to the autoload EventBus [v1.1].
## The only place where src/sim objects meet the global bus.

var _bound: Array[Dictionary] = []


func bind_run(run: RunController) -> void:
	_link(run.phase_changed, EventBus.phase_changed.emit)
	_link(run.session_started, EventBus.session_started.emit)
	for sig: String in ["boss_announced", "quarter_resolved", "run_ended"]:
		if run.has_signal(sig):
			_link(Signal(run, sig), Signal(EventBus, sig).emit)


func bind_session(s: SessionRunner) -> void:
	_link(s.market.tick_updated, EventBus.market_tick_updated.emit)
	_link(s.market.jump_warning_issued, EventBus.jump_warning_issued.emit)
	_link(s.market.jump_event_announced, EventBus.jump_event_announced.emit)
	_link(s.wall_smashed, _on_wall_smashed)
	_link(s.portfolio_updated, EventBus.portfolio_updated.emit)
	_link(s.margin_warning_changed, EventBus.margin_warning_changed.emit)
	_link(s.margin_called, _on_margin_called)
	_link(s.position_opened, EventBus.position_opened.emit)
	_link(s.position_closed, EventBus.position_closed.emit)


func unbind_all() -> void:
	for b: Dictionary in _bound:
		var sig: Signal = b["signal"]
		var cb: Callable = b["callable"]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_bound.clear()


func _link(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)
		_bound.append({"signal": sig, "callable": cb})


func _on_wall_smashed(ticker: String, tier: int, wall_price: float, bonus: float, momentum: float) -> void:
	EventBus.wall_smashed.emit(ticker, tier, wall_price, bonus, momentum)
	EventBus.screen_shake_requested.emit(6.0 + 2.0 * float(tier), 0.22)


func _on_margin_called(final_equity: float) -> void:
	EventBus.margin_called.emit(final_equity)
	EventBus.screen_shake_requested.emit(16.0, 0.5)


func _exit_tree() -> void:
	unbind_all()
