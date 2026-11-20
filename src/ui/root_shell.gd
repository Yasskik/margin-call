extends Control
## Screen router + global layers: liquid shader backdrop, screen host (shaken), CRT overlay,
## popup layer. Owns the RunController and the EventBridge.

const BG_SHADER: Shader = preload("res://src/shaders/liquid_terminal_bg.gdshader")
const CRT_SHADER: Shader = preload("res://src/shaders/crt_bloom_overlay.gdshader")

var run: RunController
var bridge: EventBridge
var terminal: MainTerminal
var screen_host: Control
var bg_mat: ShaderMaterial
var crt_mat: ShaderMaterial
var popup_layer: Control
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _glitch: float = 0.0
var _warning: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layers()
	bridge = EventBridge.new()
	add_child(bridge)
	EventBus.screen_shake_requested.connect(_on_shake)
	EventBus.wall_smashed.connect(func(_t: String, _k: int, _p: float, _b: float, _m: float) -> void: _glitch = 1.0)
	EventBus.margin_warning_changed.connect(func(on: bool, _m: float) -> void:
		_warning = on
		if on:
			_glitch = 1.0)
	start_new_run(int(Time.get_unix_time_from_system()) % 1000000)
	if DevAutopilot.requested():
		var ap: DevAutopilot = DevAutopilot.new()
		ap.shell = self
		add_child(ap)


func _build_layers() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = BG_SHADER
	bg.material = bg_mat
	add_child(bg)
	screen_host = Control.new()
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_host)
	var crt: ColorRect = ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_mat = ShaderMaterial.new()
	crt_mat.shader = CRT_SHADER
	crt.material = crt_mat
	add_child(crt)
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)
	FloatingPopup.layer = popup_layer


func start_new_run(seed_value: int) -> void:
	bridge.unbind_all()
	run = RunController.new(DataRegistry.loader, seed_value)
	bridge.bind_run(run)
	run.start_run()
	bridge.bind_session(run.session)
	if terminal == null:
		terminal = MainTerminal.new()
		screen_host.add_child(terminal)
		terminal.build(run)
	terminal.bind_session(run.session)
	terminal.tray.show_perks([DataRegistry.loader.get_perk("perk_bloomberg_trial")] as Array[PerkDef], 5)


func _on_shake(intensity: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, intensity)
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		screen_host.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_time <= 0.0:
			_shake_strength = 0.0
			screen_host.position = Vector2.ZERO
	_glitch = maxf(0.0, _glitch - delta / 0.18)
	crt_mat.set_shader_parameter("glitch_intensity", _glitch)
	crt_mat.set_shader_parameter("warning_pulse", 1.0 if _warning else 0.0)
	bg_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	if run != null and run.session != null:
		var regime: String = run.session.market.regime
		var speeds: Dictionary = {"CALM": 0.12, "BULL_MANIA": 0.25, "VOLATILE": 0.5, "CRASH": 0.7}
		bg_mat.set_shader_parameter("swirl_speed", float(speeds.get(regime, 0.12)))
		bg_mat.set_shader_parameter("bull_gold", run.session.momentum.momentum / 100.0)
		bg_mat.set_shader_parameter("heat_bleed", 1.0 if _warning else (0.45 if regime == "CRASH" else 0.0))
		bg_mat.set_shader_parameter("shake_amount", 1.0 if regime == "CRASH" else 0.0)
