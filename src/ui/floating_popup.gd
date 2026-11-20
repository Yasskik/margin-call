class_name FloatingPopup
extends Label
## Rising animated number popup (+$4,200, x2.0, WALL SMASH!) with elastic spawn and fade-out.

static var layer: Control = null

var _rise: float = 90.0
var _duration: float = 0.95


## Spawns a popup centred on a global screen position inside the shared popup layer.
static func spawn_global(text_value: String, color: Color, global_pos: Vector2, font_size: int = 40, rise: float = 90.0) -> FloatingPopup:
	if layer == null or not is_instance_valid(layer):
		return null
	var p: FloatingPopup = FloatingPopup.new()
	p.text = text_value
	p._rise = rise
	p.add_theme_font_override("font", ThemeTokens.font_mono_bold)
	p.add_theme_font_size_override("font_size", font_size)
	p.add_theme_color_override("font_color", color)
	p.add_theme_color_override("font_outline_color", ThemeTokens.BG_DEEP_NAVY)
	p.add_theme_constant_override("outline_size", 10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	p.reset_size()
	var local: Vector2 = layer.get_global_transform().affine_inverse() * global_pos
	p.position = local - p.size * 0.5
	p.pivot_offset = p.size * 0.5
	return p


func _ready() -> void:
	scale = Vector2(0.4, 0.4)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - _rise, _duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(_duration - 0.4)
	tw.chain().tween_callback(queue_free)
