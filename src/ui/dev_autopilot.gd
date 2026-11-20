class_name DevAutopilot
extends Node
## Developer/CI helper (inactive unless launched with user args after `--`):
##   --autopilot=<scenario>  scripted inputs for README screenshots / smoke tests
##   --shotdir=<abs dir>     where PNG screenshots are written
## Never used in normal play.

var shell: Control
var scenario: String = ""
var shot_dir: String = ""
var _t: float = 0.0
var _steps: Array[Dictionary] = []


static func requested() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--autopilot="):
			return true
	return false


static func scenario_name() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--autopilot="):
			return a.get_slice("=", 1)
	return ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--autopilot="):
			scenario = a.get_slice("=", 1)
		elif a.begins_with("--shotdir="):
			shot_dir = a.get_slice("=", 1)
	_steps = AutopilotScenarios.build(scenario)


func _process(delta: float) -> void:
	_t += delta
	while not _steps.is_empty() and _t >= float(_steps[0]["at"]):
		var s: Dictionary = _steps.pop_front()
		AutopilotScenarios.run_step(self, s)


func snap(name: String) -> void:
	if shot_dir == "":
		return
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var path: String = shot_dir.path_join(name + ".png")
	img.save_png(path)
	print("AUTOPILOT shot saved: ", path)
