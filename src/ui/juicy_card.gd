class_name JuicyCard
extends Control
## Balatro-style card: idle sine bob/tilt offset by slot_index, mouse-tracked fake-3D foil shader,
## hover lift 1.0 -> 1.08 and a TRANS_BACK trigger pop that spawns a FloatingPopup (Part 3.4).

signal card_pressed(card: JuicyCard)

const CARD_SHADER: Shader = preload("res://src/shaders/card_tilt_foil.gdshader")

var card_id: String = ""
var slot_index: int = 0
var accent: Color = ThemeTokens.LUXURY_GOLD
var interactive: bool = true
var body: Control
var face: ColorRect
var title_label: Label
var tag_label: Label
var desc_label: Label
var footer_label: Label
var _mat: ShaderMaterial
var _t: float = 0.0
var _tilt: Vector2 = Vector2.ZERO
var _target_tilt: Vector2 = Vector2.ZERO
var _hover: bool = false
var _popping: bool = false
var _pop_rot: float = 0.0
var _glow: float = 0.0


func setup(id: String, title: String, tag: String, description: String, footer: String, accent_color: Color, foil_tier: int, card_size: Vector2 = Vector2(200, 260)) -> JuicyCard:
	card_id = id
	accent = accent_color
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	body = Control.new()
	body.size = card_size
	body.pivot_offset = card_size * 0.5
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	face = ColorRect.new()
	face.size = card_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = CARD_SHADER
	_mat.set_shader_parameter("accent_color", accent_color)
	_mat.set_shader_parameter("base_color", ThemeTokens.PANEL_SLATE)
	_mat.set_shader_parameter("foil_tier", foil_tier)
	face.material = _mat
	body.add_child(face)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(16, 14)
	box.size = card_size - Vector2(32, 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	tag_label = _lbl(tag, 15, accent_color, true)
	title_label = _lbl(title, 20, ThemeTokens.TEXT_IVORY, true)
	desc_label = _lbl(description, 15, ThemeTokens.TEXT_MUTED, false)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.max_lines_visible = 5
	desc_label.clip_text = true
	for l: Label in [tag_label, title_label, desc_label]:
		box.add_child(l)
	box.size.y = card_size.y - 64.0
	footer_label = _lbl(footer, 17, ThemeTokens.LUXURY_GOLD, true)
	footer_label.position = Vector2(16, card_size.y - 40.0)
	footer_label.size = Vector2(card_size.x - 32.0, 26.0)
	body.add_child(footer_label)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void:
		_hover = false
		_target_tilt = Vector2.ZERO)
	return self


func _lbl(txt: String, fsize: int, col: Color, bold: bool) -> Label:
	var l: Label = ThemeTokens.make_label(txt, fsize, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_footer(txt: String, col: Color = ThemeTokens.LUXURY_GOLD) -> void:
	footer_label.text = txt
	footer_label.add_theme_color_override("font_color", col)


func set_dimmed(on: bool) -> void:
	_mat.set_shader_parameter("dimmed", 0.75 if on else 0.0)


func _process(delta: float) -> void:
	if body == null:
		return
	_t += delta
	var i: float = float(slot_index)
	var y_off: float = 2.5 * sin(2.2 * _t + 0.7 * i)
	var theta: float = 0.018 * cos(1.7 * _t + 0.5 * i)
	body.position = Vector2(0.0, y_off - (6.0 if _hover and interactive else 0.0))
	body.rotation = theta + _pop_rot
	_tilt = _tilt.lerp(_target_tilt, clampf(10.0 * delta, 0.0, 1.0))
	_mat.set_shader_parameter("tilt_rot", _tilt)
	_glow = maxf(0.0, _glow - delta * 3.0)
	_mat.set_shader_parameter("glow", _glow)
	if not _popping:
		var target: float = 1.08 if _hover and interactive else 1.0
		body.scale = body.scale.lerp(Vector2(target, target), clampf(12.0 * delta, 0.0, 1.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Vector2 = (event as InputEventMouseMotion).position
		var half: Vector2 = size * 0.5
		_target_tilt = ((local - half) / half).clamp(Vector2(-1, -1), Vector2(1, 1))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and interactive:
			card_pressed.emit(self)


## Scale punch 1.0 -> 1.28 (0.07 s, TRANS_BACK, +/-6 deg) then elastic settle (0.12 s).
func play_trigger_pop(label_text: String, color: Color, shake: float = 3.0) -> void:
	_popping = true
	_glow = 1.0
	var dir: float = 1.0 if randf() < 0.5 else -1.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(body, "scale", Vector2(1.28, 1.28), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_pop_rot", deg_to_rad(6.0) * dir, 0.07)
	tw.chain().set_parallel(true)
	tw.tween_property(body, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_pop_rot", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void: _popping = false)
	FloatingPopup.spawn_global(label_text, color, global_position + Vector2(size.x * 0.5, -10.0), 34, 70.0)
	EventBus.screen_shake_requested.emit(shake, 0.12)
