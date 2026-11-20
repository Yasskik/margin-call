class_name TestAssert
extends RefCounted
## Minimal assertion collector for the headless runner (no autoloads, no Nodes).

var passed: int = 0
var failed: int = 0
var current: String = ""
var failures: PackedStringArray = PackedStringArray()


func ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		failures.append("%s: %s" % [current, msg])
		printerr("  FAIL %s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func near(a: float, b: float, tol: float, msg: String) -> void:
	ok(absf(a - b) <= tol, "%s (got %.9f, expected %.9f +/- %s)" % [msg, a, b, str(tol)])
