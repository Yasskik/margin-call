extends Node
## Typed global signals (Part 3.2). Decouples presentation from the headless sim.
## Sim classes never reference this autoload; src/ui/event_bridge.gd forwards their signals here.

# --- Market & Session Signals ---
signal session_started(quarter: int, session_idx: int, boss_id: String)
signal market_tick_updated(ticker: String, price: float, bid: float, ask: float, regime: String, tick_idx: int)
signal jump_event_announced(ticker: String, headline: String, impact_pct: float)
signal jump_warning_issued(ticker: String, seconds_ahead: float, direction_hint: int) # direction_hint: +1/-1 only with Fed Whisperer, else 0 [v1.1]
signal wall_smashed(ticker: String, wall_tier: int, wall_price: float, bonus_cash: float, momentum: float)

# --- Portfolio & Risk Signals ---
signal position_opened(pos_id: String, ticker: String, side: String, leverage: int, collateral: float)
signal position_closed(pos_id: String, realized_pnl: float, trigger_steps: Array)
signal portfolio_updated(cash: float, equity: float, gross_exposure: float, margin_ratio: float)
signal margin_warning_changed(is_warning: bool, margin_ratio: float)
signal margin_called(final_equity: float)

# --- Combo & Juice Signals ---
signal combo_step_played(source_id: String, label: String, color_hex: String, pitch_step: int, shake_strength: float)
signal combo_sequence_finished(total_payout: float)
signal screen_shake_requested(intensity: float, duration: float)
signal algo_triggered(algo_id: String, label: String, value: float) # [v1.1]

# --- Life Sim & SEC Heat Signals ---
signal life_stats_updated(burn_rate: float, stress: float, sleep: float, prestige: int)
signal sec_heat_changed(stars: float, delta: float, reason: String)
signal fbi_raid_triggered(escape_target: float)

# --- Flow & Phase Signals ---
signal phase_changed(new_phase: String) # "MENU", "TRADING", "SETTLEMENT", "AFTER_HOURS", "BOSS_AUDIT", "GAME_OVER", "VICTORY"
signal boss_announced(boss_id: String, boss_name: String, is_fbi_raid: bool) # [v1.1]
signal quarter_resolved(quarter: int, passed: bool, equity: float, target: float) # [v1.1]
signal run_ended(outcome: String, summary: Dictionary) # outcome: "VICTORY", "MARGIN_CALL", "INSOLVENCY", "BURNOUT", "INDICTED"; drives receipt_screen [v1.1]
