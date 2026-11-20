#!/usr/bin/env bash
# AGENTS.md 1.3 verification gate: parse check, headless tests, modularity audit.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0
"$GODOT" --headless --import >/dev/null 2>&1
echo "== 1. Parse check (godot --headless --quit)"
out=$(timeout 120 "$GODOT" --headless --quit 2>&1)
if echo "$out" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|WARNING:" ; then echo "   FAIL"; fail=1; else echo "   OK (zero script errors/warnings)"; fi
if [ -f tests/test_runner.gd ]; then
  echo "== 2. Headless unit tests"
  timeout 600 "$GODOT" --headless -s tests/test_runner.gd 2>&1 | grep -v "^Godot Engine" | tail -n 60
  rc=${PIPESTATUS[0]}
  echo "   test_runner exit code: $rc"; [ "$rc" -ne 0 ] && fail=1
fi
echo "== 3. Modularity audit"
over=$(find src tests -name '*.gd' -exec wc -l {} + | awk '$2 != "total" && $1 > 300 {print}')
if [ -n "$over" ]; then echo "   FAIL: files over 300 lines:"; echo "$over"; fail=1; else echo "   OK: no .gd file over 300 lines"; fi
banned=$(grep -nE "\b(Node|Control|CanvasItem|SceneTree|get_tree\(|Input\.|Tween|AudioStreamPlayer|EventBus|ThemeTokens|DataRegistry|src/ui)\b" src/sim/*.gd src/models/*.gd 2>/dev/null)
if [ -n "$banned" ]; then echo "   FAIL: banned references in sim/models:"; echo "$banned"; fail=1; else echo "   OK: src/sim + src/models are UI/autoload-free"; fi
exit $fail
