shader_type canvas_item;
// Domain-warped fluid plasma: deep navy base, teal currents, gold ribbons (Part 3.4).
// GL Compatibility + Forward+ safe: no screen texture, no derivatives, no loops > 4.

uniform float swirl_speed : hint_range(0.0, 2.0) = 0.15;
uniform float heat_bleed : hint_range(0.0, 1.0) = 0.0;
uniform float bull_gold : hint_range(0.0, 1.0) = 0.0;
uniform float shake_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 navy : source_color = vec4(0.039, 0.086, 0.157, 1.0);
uniform vec4 teal : source_color = vec4(0.055, 0.302, 0.361, 1.0);
uniform vec4 gold : source_color = vec4(0.831, 0.686, 0.216, 1.0);
uniform vec4 crimson : source_color = vec4(1.0, 0.231, 0.361, 1.0);
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * swirl_speed;
	uv += vec2(sin(TIME * 47.0), cos(TIME * 53.0)) * 0.004 * shake_amount;
	vec2 p = vec2(uv.x * aspect, uv.y) * 2.2;
	vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3 - t)));
	vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7 + t * 0.6, 9.2)), fbm(p + 3.0 * q + vec2(8.3, 2.8 - t * 0.4)));
	float f = fbm(p + 3.5 * r);
	vec3 col = navy.rgb;
	col = mix(col, teal.rgb, smoothstep(0.35, 0.95, f) * 0.55);
	// gold veins: thin ribbons where the warped field crosses an iso-line
	float ribbon = 1.0 - smoothstep(0.0, 0.035 + 0.04 * bull_gold, abs(fract(f * 3.0 + t * 0.2) - 0.5));
	col += gold.rgb * ribbon * (0.06 + 0.32 * bull_gold) * smoothstep(0.3, 0.8, r.x);
	// crimson edge bleed for SEC heat / margin warning / crash
	vec2 c = UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.25)));
	col = mix(col, crimson.rgb * 0.55, edge * heat_bleed * (0.75 + 0.25 * sin(TIME * 6.0)));
	// vignette into deep navy to keep panels readable
	col = mix(col, navy.rgb * 0.6, smoothstep(0.45, 0.95, length(c)) * 0.6);
	COLOR = vec4(col, 1.0);
}
