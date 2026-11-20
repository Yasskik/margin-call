shader_type canvas_item;
// Fake-3D perspective card with a diagonal metallic foil band (Part 3.4).
// Draws the card body procedurally from UV so it works on any ColorRect (Compatibility safe).

uniform vec2 tilt_rot = vec2(0.0, 0.0);       // -1..1, lerped from mouse position
uniform int foil_tier : hint_range(0, 3) = 1;   // 1 Silver, 2 Emerald/Cyan, 3 Liquid Gold Hologram
uniform vec4 base_color : source_color = vec4(0.071, 0.137, 0.239, 1.0);
uniform vec4 accent_color : source_color = vec4(0.831, 0.686, 0.216, 1.0);
uniform float corner_radius = 0.07;
uniform float border_width = 0.018;
uniform float glow = 0.0;                       // trigger pop flash 0..1
uniform float dimmed = 0.0;                     // disabled / locked look

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// perspective warp: tilt shrinks the far edge and shifts UVs
	vec2 uv = UV - 0.5;
	float persp = 1.0 + tilt_rot.x * uv.x * 0.35 + tilt_rot.y * uv.y * 0.35;
	uv = uv / persp;
	uv += tilt_rot * 0.02;
	float d = rounded_box(uv, vec2(0.5 - 0.012), corner_radius);
	if (d > 0.0) {
		discard;
	}
	vec3 col = base_color.rgb;
	// soft vertical gradient for depth
	col *= 0.85 + 0.3 * (0.5 - uv.y);
	// inner border in the accent colour
	float border = smoothstep(-border_width - 0.004, -border_width, d);
	col = mix(col, accent_color.rgb, border * 0.9);
	// foil band sweeps with tilt
	float band_pos = uv.x * 0.8 + uv.y * 0.6 + tilt_rot.x * 0.6 - tilt_rot.y * 0.4;
	float band = exp(-pow((band_pos - 0.1) * 6.0, 2.0));
	vec3 foil = vec3(0.85, 0.88, 0.92);
	if (foil_tier == 2) {
		foil = mix(vec3(0.0, 0.9, 0.46), vec3(0.22, 0.74, 0.97), 0.5 + 0.5 * sin(band_pos * 9.0 + TIME));
	} else if (foil_tier >= 3) {
		vec3 holo = 0.5 + 0.5 * cos(6.2831 * (band_pos * 1.4 + vec3(0.0, 0.33, 0.67)) + TIME * 0.8);
		foil = mix(vec3(0.83, 0.69, 0.22), holo, 0.35);
	}
	float strength = foil_tier <= 0 ? 0.0 : (0.10 + 0.07 * float(foil_tier));
	col += foil * band * strength;
	col += accent_color.rgb * glow * 0.45;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * 0.6, dimmed);
	COLOR = vec4(col, 1.0);
}
