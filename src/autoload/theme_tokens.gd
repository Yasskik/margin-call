extends Node
## Palette, fonts, Liquid-Glass StyleBox factory and tabular currency formatting.
## Every UI script pulls colours and fonts from here (AGENTS.md 1.2).

const BG_DEEP_NAVY: Color = Color("#0A1628")
const PANEL_SLATE: Color = Color("#12233D")
const BORDER_HAIRLINE: Color = Color("#243B5E")
const LUXURY_GOLD: Color = Color("#D4AF37")
const PROFIT_EMERALD: Color = Color("#00E676")
const MARGIN_CRIMSON: Color = Color("#FF3B5C")
const ALGO_CYAN: Color = Color("#38BDF8")
const TEXT_IVORY: Color = Color("#F1F5F9")
const TEXT_MUTED: Color = Color("#94A3B8")
const DEEP_TEAL: Color = Color("#0E4D5C")
const AMBER: Color = Color("#F59E0B")

const REGIME_COLORS: Dictionary = {
	"CALM": Color("#38BDF8"),
	"BULL_MANIA": Color("#D4AF37"),
	"VOLATILE": Color("#F59E0B"),
	"CRASH": Color("#FF3B5C"),
}
const RARITY_COLORS: Dictionary = {
	"COMMON": Color("#94A3B8"),
	"UNCOMMON": Color("#38BDF8"),
	"RARE": Color("#00E676"),
	"LEGENDARY": Color("#D4AF37"),
}
const PHASE_COLORS: Dictionary = {
	"BASE_ALPHA": Color("#00E676"),
	"FLAT_ALPHA": Color("#38BDF8"),
	"ADDITIVE_MULT": Color("#D4AF37"),
	"COMPOUND_XMULT": Color("#FF3B5C"),
}

const FONT_MONO_PATH: String = "res://assets/fonts/JetBrainsMono-Regular.ttf"
const FONT_MONO_BOLD_PATH: String = "res://assets/fonts/JetBrainsMono-Bold.ttf"
const FONT_DISPLAY_PATH: String = "res://assets/fonts/Cinzel-Bold.ttf"

var font_mono: Font
var font_mono_bold: Font
var font_display: Font


func _ready() -> void:
	font_mono = _load_font(FONT_MONO_PATH, ["JetBrains Mono", "DejaVu Sans Mono", "Consolas", "monospace"], 400)
	font_mono_bold = _load_font(FONT_MONO_BOLD_PATH, ["JetBrains Mono", "DejaVu Sans Mono", "Consolas", "monospace"], 700)
	font_display = _load_font(FONT_DISPLAY_PATH, ["Cinzel", "Trajan Pro", "Georgia", "serif"], 700)
	var theme: Theme = Theme.new()
	theme.default_font = font_mono
	theme.default_font_size = 22
	get_tree().root.theme = theme


## Loads a bundled TTF; falls back cleanly to a SystemFont if the file is missing.
func _load_font(path: String, fallback_names: Array[String], weight: int) -> Font:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			return res as Font
	push_warning("ThemeTokens: font missing at %s, using system fallback." % path)
	var sys: SystemFont = SystemFont.new()
	sys.font_names = PackedStringArray(fallback_names)
	sys.font_weight = weight
	return sys


## Rounded translucent "Liquid Glass" panel with a crisp 1 px hairline.
func create_glass_panel_stylebox(bg_alpha: float = 0.82, border: Color = BORDER_HAIRLINE, radius: int = 10, border_width: int = 1) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_SLATE, bg_alpha)
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 6
	sb.anti_aliasing = true
	return sb


func create_pill_stylebox(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


## Tabular currency: "$12,345", "-$1,234.50", "+$4,200" (with show_sign).
func format_currency(value: float, decimals: int = 0, show_sign: bool = false) -> String:
	var neg: bool = value < 0.0
	var abs_val: float = absf(value)
	var factor: float = pow(10.0, decimals)
	var rounded: float = roundf(abs_val * factor) / factor
	var whole: int = int(floorf(rounded))
	var digits: String = str(whole)
	var grouped: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	var text: String = "$" + grouped
	if decimals > 0:
		var frac: int = int(roundf((rounded - float(whole)) * factor))
		text += "." + str(frac).pad_zeros(decimals)
	if neg and rounded > 0.0:
		return "-" + text
	if show_sign:
		return "+" + text
	return text


## Compact money for big headline numbers: $1.25M, $18.0M, $950K.
func format_compact(value: float) -> String:
	var a: float = absf(value)
	var sign: String = "-" if value < 0.0 else ""
	if a >= 1000000.0:
		return "%s$%.2fM" % [sign, a / 1000000.0]
	if a >= 100000.0:
		return "%s$%.0fK" % [sign, a / 1000.0]
	return format_currency(value)


func format_pct(ratio: float, decimals: int = 1, show_sign: bool = false) -> String:
	var txt: String = ("%." + str(decimals) + "f%%") % (ratio * 100.0)
	if show_sign and ratio >= 0.0:
		return "+" + txt
	return txt


func regime_color(regime: String) -> Color:
	return REGIME_COLORS.get(regime, TEXT_MUTED)


func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, TEXT_MUTED)


func phase_color(phase: String) -> Color:
	return PHASE_COLORS.get(phase, TEXT_IVORY)


## Styled label factory (keeps fonts/colours centralised).
func make_label(text: String, size: int = 22, color: Color = TEXT_IVORY, bold: bool = false, display: bool = false) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	var f: Font = font_display if display else (font_mono_bold if bold else font_mono)
	lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func style_button(btn: Button, accent: Color, size: int = 22, filled: bool = false) -> void:
	var normal: StyleBoxFlat = create_pill_stylebox(Color(accent, 0.22) if filled else Color(PANEL_SLATE, 0.9), Color(accent, 0.85))
	var hover: StyleBoxFlat = create_pill_stylebox(Color(accent, 0.38), accent)
	var pressed: StyleBoxFlat = create_pill_stylebox(Color(accent, 0.55), accent)
	var disabled: StyleBoxFlat = create_pill_stylebox(Color(PANEL_SLATE, 0.5), Color(BORDER_HAIRLINE, 0.8))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", font_mono_bold)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", TEXT_IVORY)
	btn.add_theme_color_override("font_hover_color", TEXT_IVORY)
	btn.add_theme_color_override("font_pressed_color", BG_DEEP_NAVY if filled else TEXT_IVORY)
	btn.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED, 0.6))
	btn.focus_mode = Control.FOCUS_NONE
