#!/usr/bin/env python3
"""Authoring helper: regenerates data/contacts_perks.json (the JSON is the runtime source of truth)."""
import json, sys, os

G, E, C, R, CY = "#D4AF37", "#00E676", "#FF3B5C", "#00E676", "#38BDF8"
def perk(id, name, rarity, arch, cost, minp, desc, hook, phase, cond, eff, accent, foil, **kw):
    d = {"id": id, "name": name, "rarity": rarity, "archetype": arch, "cost": cost, "min_prestige": minp,
         "description": desc, "trigger_hook": hook, "phase": phase, "condition": cond, "effect": eff,
         "accent_color": accent, "foil_tier": foil}
    d.update(kw); return d
A = {"type": "ALWAYS"}; WIN = {"type": "TRADE_PROFIT_POSITIVE"}
def ALL(*c): return {"type": "ALL", "conditions": list(c)}
P = {"op": "PASSIVE_ONLY"}
perks = [
 perk("perk_bloomberg_trial","Bloomberg Trial","COMMON","MOMENTUM",2000,0,"Starter terminal: +15% Wall Smash bonus.","PASSIVE","PASSIVE",A,P,G,1,passive_mods=[{"key":"wall_bonus_mult","value":1.15}],shop_eligible=False,tags=["MOMENTUM"]),
 perk("perk_margin_cowboy","Margin Cowboy","COMMON","LEVERAGE_DEGEN",2500,0,"+0.4x Mult on trades opened at 5x leverage or higher.","ON_TRADE_CLOSE","ADDITIVE_MULT",{"type":"LEVERAGE_GTE","value":5},{"op":"ADD_MULT","amount":0.4},G,1,tags=["LEVERAGE"]),
 perk("perk_adrenaline_desk","Adrenaline Desk","UNCOMMON","LEVERAGE_DEGEN",4000,0,"+$1,200 Flat Alpha per 10 Stress on winning trades.","ON_TRADE_CLOSE","FLAT_ALPHA",WIN,{"op":"DYNAMIC_FLAT_BY_STAT","stat":"stress","per_unit":1200,"unit_size":10},CY,1,requires_feature="life_sim",tags=["LEVERAGE","STRESS"]),
 perk("perk_knife_catcher","Knife Catcher","RARE","LEVERAGE_DEGEN",6500,0,"x2.0 Mult on trades entered during CRASH that close green.","ON_TRADE_CLOSE","COMPOUND_XMULT",ALL({"type":"ENTRY_REGIME_IS","value":"CRASH"},WIN),{"op":"XMULT","amount":2.0},C,2,tags=["LEVERAGE","CRASH"]),
 perk("perk_liquidation_flirt","Liquidation Flirt","RARE","LEVERAGE_DEGEN",7000,0,"x3.0 final session profit if your Margin dipped below 22% and you survived.","ON_SESSION_END","COMPOUND_XMULT",ALL({"type":"MIN_MARGIN_BELOW","value":0.22},{"type":"SESSION_PROFIT_POSITIVE"}),{"op":"XMULT","amount":3.0},C,2,tags=["LEVERAGE","RISK"]),
 perk("perk_bear_raid","Bear Raid Syndicate","COMMON","SHORT_BEAR",2500,0,"Shorts build Kinetic Momentum 40% faster.","PASSIVE","PASSIVE",A,P,G,1,passive_mods=[{"key":"momentum_gain_short","value":1.4}],tags=["SHORT","MOMENTUM"]),
 perk("perk_forensic_accountant","Forensic Accountant","UNCOMMON","SHORT_BEAR",4500,0,"-50% Short Borrow on Biotech/Meme and +0.6x Mult on Shorts.","ON_TRADE_CLOSE","ADDITIVE_MULT",{"type":"SIDE_IS","value":"SHORT"},{"op":"ADD_MULT","amount":0.6},G,1,passive_mods=[{"key":"borrow_mult","value":0.5,"sectors":["BIOTECH","MEME"]}],tags=["SHORT"]),
 perk("perk_doomsday_prophet","Doomsday Prophet","UNCOMMON","SHORT_BEAR",4000,0,"+$800 Flat Alpha per red candle printed during CRASH on a ticker you hold.","ON_SESSION_END","FLAT_ALPHA",A,{"op":"DYNAMIC_FLAT_BY_STAT","stat":"session_crash_red_candles","per_unit":800,"unit_size":1},CY,1,tags=["SHORT","CRASH"]),
 perk("perk_big_short","The Big Short","RARE","SHORT_BEAR",8000,0,"x2.5 Mult on winning Shorts once you break 3+ Support Floors in one session.","ON_TRADE_CLOSE","COMPOUND_XMULT",ALL({"type":"SIDE_IS","value":"SHORT"},{"type":"SESSION_FLOORS_GTE","value":3},WIN),{"op":"XMULT","amount":2.5},C,3,tags=["SHORT","WALLS"]),
 perk("perk_burner_phone","Burner Phone","UNCOMMON","INSIDER_HEAT",4000,0,"+$2,000 Flat Alpha per active SEC Star on winning trades.","ON_TRADE_CLOSE","FLAT_ALPHA",WIN,{"op":"DYNAMIC_FLAT_BY_STAT","stat":"sec_heat_stars","per_unit":2000,"unit_size":1},CY,1,requires_feature="life_sim",tags=["INSIDER"]),
 perk("perk_cayman_courier","Cayman Courier","RARE","INSIDER_HEAT",6000,0,"-25% Quarterly Tax per SEC Star (max 75%).","PASSIVE","PASSIVE",A,P,G,2,passive_mods=[{"key":"tax_cut_per_star","value":0.25,"max":0.75}],requires_feature="life_sim",tags=["INSIDER","TAX"]),
 perk("perk_lobbyist_dinner","Lobbyist Dinner","RARE","INSIDER_HEAT",7500,25,"x1.5 Mult on winning trades while Prestige >= 40. Paying Burn Rate cools 0.5 SEC Stars.","ON_TRADE_CLOSE","COMPOUND_XMULT",ALL({"type":"STAT_GTE","stat":"prestige","value":40},WIN),{"op":"XMULT","amount":1.5},C,2,passive_mods=[{"key":"burn_payment_heat_cool","value":0.5}],tags=["INSIDER","PRESTIGE"]),
 perk("perk_shadow_senator","Shadow Senator","LEGENDARY","INSIDER_HEAT",14000,50,"Gains x0.6 Compound Mult per active SEC Star on every winning trade.","ON_TRADE_CLOSE","COMPOUND_XMULT",WIN,{"op":"DYNAMIC_XMULT_BY_STAT","stat":"sec_heat_stars","base":1.0,"per_unit":0.6},C,3,requires_feature="life_sim",tags=["INSIDER"]),
 perk("perk_fiber_optic","Fiber Optic Cable","UNCOMMON","ALGO_MOMENTUM",4000,0,"Zero bid-ask slippage on every fill.","PASSIVE","PASSIVE",A,P,CY,1,passive_mods=[{"key":"spread_mult","value":0.0}],tags=["ALGO"]),
 perk("perk_tape_reader","Tape Reader","UNCOMMON","MOMENTUM",4500,0,"Permanently gains +0.15x Additive Mult every time you shatter a Resistance Wall.","ON_WALL_SMASH","ADDITIVE_MULT",A,{"op":"SCALING_ADD_MULT","increment":0.15,"initial":0.0},G,1,tags=["MOMENTUM","WALLS","SCALING"]),
 perk("perk_quant_phd","Quant PhD","RARE","ALGO_MOMENTUM",6000,0,"+0.35x Mult per distinct equipped Algo.","ON_TRADE_CLOSE","ADDITIVE_MULT",A,{"op":"DYNAMIC_ADD_MULT_BY_STAT","stat":"distinct_algos","per_unit":0.35},G,2,requires_feature="algos_live",tags=["ALGO"]),
 perk("perk_hft_arbitrage","High-Frequency Arbitrage","UNCOMMON","ALGO_MOMENTUM",4500,0,"+$300 Flat Alpha for every 5 ticks a winning trade was held in profit.","ON_TRADE_CLOSE","FLAT_ALPHA",WIN,{"op":"DYNAMIC_FLAT_BY_STAT","stat":"trade_ticks_in_profit","per_unit":300,"unit_size":5},CY,1,tags=["ALGO","HOLD"]),
 perk("perk_fed_whisperer","Fed Whisperer","RARE","ALGO_MOMENTUM",6000,0,"Jump Warnings reveal direction and arrive 3 s early instead of 1.5 s.","PASSIVE","PASSIVE",A,P,CY,2,passive_mods=[{"key":"fed_whisperer","value":1}],tags=["SIGNALS"]),
 perk("perk_stop_loss_guardian","Stop-Loss Guardian","COMMON","ALGO_MOMENTUM",3000,0,"Auto-closes your worst position before Margin hits 17% (1 charge per Quarter).","PASSIVE","PASSIVE",A,P,E,1,passive_mods=[{"key":"stop_loss_threshold","value":0.17,"charges_per_quarter":1}],tags=["DEFENSE"]),
]
starter = {"perk_bloomberg_trial","perk_margin_cowboy","perk_knife_catcher","perk_tape_reader","perk_shadow_senator","perk_fiber_optic","perk_stop_loss_guardian"}
if len(sys.argv) > 1 and sys.argv[1] == "starter":
    perks = [p for p in perks if p["id"] in starter]
out = os.path.join(os.path.dirname(__file__), "..", "data", "contacts_perks.json")
with open(out, "w") as f:
    json.dump({"schema_version": 1, "perks": perks}, f, indent=2); f.write("\n")
print(len(perks), "perks written")
