# AGENTS.md — MARGIN CALL AI Coding Constitution

> Extracted verbatim from Part 1 of `docs/MARGIN_CALL_MASTER_BLUEPRINT.md` (Stage 0). Read this before touching any file. The blueprint is the source of truth for *what* to build; this file is *how* to build it.


> **Stage 0 Instruction:** Copy the exact rules below into a standalone `AGENTS.md` file at the repository root so every AI agent reads it automatically.

## 1.1 Non-Negotiable Architecture Rules

1. **Strict Headless Simulation (`src/sim/` & `src/models/`):**
   * Every script in `src/sim/` and `src/models/` MUST extend `RefCounted` (or `Resource`).
   * **BANNED in `src/sim/`:** `Node`, `Control`, `CanvasItem`, `SceneTree`, `get_tree()`, `Input`, `Tween`, `AudioStreamPlayer`, or any reference to `src/ui/`.
   * All randomness MUST flow through an injected `RNGService` instance (`rng.randf()`, `rng.rand_gaussian()`). Never call global `randf()` or `randi()` inside simulation math—every run must be $100\%$ deterministic from its seed.
2. **Decoupled Presentation (`src/ui/`):**
   * UI scripts NEVER calculate PnL, margin ratios, tax formulas, or perk multipliers.
   * UI reacts exclusively to `EventBus` signals and calls clean public command methods on `RunController` (e.g., `run_controller.open_position(...)`, `run_controller.buy_shop_item(...)`).
3. **Code-First UI (Anti-`.tscn`-Corruption Mandate):**
   * Build all UI layouts, containers, styleboxes, and signal connections programmatically in GDScript.
   * Keep `scenes/main.tscn` minimal ($\le 15$ lines). Do NOT generate complex nested `.tscn` or `.tres` files with fragile NodePaths or manual UIDs.
4. **Data-Driven Content (`data/*.json`):**
   * NEVER hardcode individual Stocks, Perks, Algos, Upgrades, Shady Deals, or Boss stats inside gameplay scripts.
   * All content definitions live in `data/*.json` and are loaded and validated at startup by `DataRegistry`. Adding new content must require editing JSON only (or registering one isolated pure effect handler in `modifier_pipeline.gd`).
5. **Strict Static Typing & Modularity Cap:**
   * Use explicit types on EVERY variable, parameter, typed array (`Array[TriggerStep]`), and return signature (`-> void`, `-> float`).
   * **Hard File Cap:** No `.gd` file may exceed **300 lines**. When a file approaches 250 lines, split cohesive sub-responsibilities into a dedicated helper class before adding features.
6. **Cross-Platform & WebGL Shader Hygiene:**
   * All `.gdshader` files MUST run identically under Godot Forward+ (Desktop) and GL Compatibility (Web/HTML5). Avoid compute shaders or desktop-only built-ins.
   * All UI layouts must support `1280x720`, `1920x1080`, and `2560x1440` with zero clipped tooltips or overlapping buttons (`canvas_items` stretch mode, `expand` aspect).

7. **Autoload-Free Simulation & Test Runner Contract [v1.1]:**
   * `src/sim/`, `src/models/`, and `tests/` NEVER reference autoload singletons (`EventBus`, `ThemeTokens`, `DataRegistry`, ...). All dependencies are injected through constructors (e.g. `MarketEngine.new(config, stocks, rng)`).
   * JSON loading and validation live in `src/sim/data_loader.gd` (pure `RefCounted`). `src/autoload/data_registry.gd` is only a thin wrapper that holds a `DataLoader` instance for the UI. Autoload names are not reliably resolvable in scripts run with `godot --headless -s`, so headless tests and `balance_simulator.gd` must construct `DataLoader` directly.
   * Sim classes communicate outward only through their own typed `signal`s (`RefCounted` can declare signals) or returned event arrays. `src/ui/event_bridge.gd` connects those to the autoload `EventBus`. Sim code never references `EventBus`.
   * `tests/test_runner.gd` MUST `extends SceneTree`, run every test file from `_init()`, print a pass/fail summary, and call `quit(0)` on full success or `quit(1)` on any failure so `scripts/build_all.sh` can gate on the exit code.

## 1.2 Visual & Audio Consistency Standards

* **Palette Compliance:** Always pull colors and fonts from `ThemeTokens` (`#0A1628` Navy, `#12233D` Slate, `#D4AF37` Gold, `#00E676` Profit Emerald, `#FF3B5C` Margin Crimson, `#38BDF8` Algo Cyan). Never scatter raw `Color(...)` literals across UI scripts.
* **Tabular Currency Formatting:** Always format numbers via `ThemeTokens.format_currency()` using monospace fonts so rolling counters never jitter horizontally.
* **No Silent Failures:** Use `assert()` in tests and explicit `push_error()` messages whenever a JSON key is missing or malformed.

## 1.3 Mandatory Verification Gate (Required After Every Stage)

Before declaring ANY stage complete, the AI agent MUST verify:
1. **Zero Parse/Type Errors:** `godot --headless --quit` exits cleanly with zero script errors.
2. **Headless Unit Tests Pass:** `godot --headless -s tests/test_runner.gd` reports $100\%$ pass rate.
3. **Modularity Audit:** No modified `.gd` script exceeds 300 lines, and zero files in `src/sim/` import or reference UI nodes.
4. **Concise Handoff:** Summarize created/modified files, new JSON keys, and any new `EventBus` signals.

