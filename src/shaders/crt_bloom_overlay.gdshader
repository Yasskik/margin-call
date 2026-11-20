shader_type canvas_item;
// Subtle toggleable 4% scanlines, radial vignette, red margin pulse and a short
// chromatic-aberration glitch on Wall Smashes / Margin Warnings (Part 3.4).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform bool scanlines_on = true;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.04;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float warning_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crimson : source_color = vec4(1.0, 0.231, 0.361, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (glitch_intensity > 0.001) {
		float off = 0.006 * glitch_intensity;
		float band = step(0.5, fract(uv.y * 24.0 + TIME * 30.0)) * glitch_intensity * 0.004;
		col.r = texture(screen_tex, uv + vec2(off + band, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(off, 0.0)).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (scanlines_on) {
		float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
		col *= 1.0 - scanline_strength * line;
	}
	vec2 c = UV - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(c));
	col *= 1.0 - vignette * v;
	float pulse = warning_pulse * (0.55 + 0.45 * sin(TIME * 7.0));
	col = mix(col, crimson.rgb, v * pulse * 0.55);
	COLOR = vec4(col, 1.0);
}
