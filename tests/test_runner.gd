extends SceneTree
## Headless CLI test runner (Rule 1.1 #7): `godot --headless -s tests/test_runner.gd`.
## Runs every suite from _init(), prints a summary, exits 0 on full pass, 1 on any failure.

const SUITES: Array[String] = [
	"res://tests/test_market_math.gd",
	"res://tests/test_sizing_and_signals.gd",
	"res://tests/test_modifier_pipeline.gd",
	"res://tests/test_run_economy.gd",
]


func _init() -> void:
	var a: TestAssert = TestAssert.new()
	var start_ms: int = Time.get_ticks_msec()
	for path: String in SUITES:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var suite: Object = script.new()
		print("SUITE %s" % path.get_file())
		for m: Dictionary in script.get_script_method_list():
			var mname: String = str(m["name"])
			if not mname.begins_with("test_"):
				continue
			a.current = path.get_file().get_basename() + "::" + mname
			var before: int = a.failed
			suite.call(mname, a)
			print("  [%s] %s" % ["PASS" if a.failed == before else "FAIL", mname])
	var passed: int = a.passed
	var failed: int = a.failed
	print("----------------------------------------------------------")
	print("RESULT: %d assertions passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - start_ms])
	print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
	quit(0 if failed == 0 else 1)
