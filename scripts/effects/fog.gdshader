shader_type canvas_item;
render_mode unshaded;
// Soft rolling mist, computed in the shader (no texture, so nothing stretches into streaks): domain-warped fractal
// noise in WORLD space, two banks drifting in different directions, plus a faint base haze so the air is never
// perfectly clear. `scale` = how many cloud cells fit in the sprite (bigger = smaller, denser wisps).
uniform vec4 fog_color : source_color = vec4(0.82, 0.9, 1.0, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float speed = 0.012;
uniform float scale = 3.0;
uniform float softness : hint_range(0.05, 0.6) = 0.35;
uniform vec2 area = vec2(2600.0, 2400.0);  // world px covered by the sprite (set by fog.gd)

varying vec2 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = wpos / area.x * scale;
	float t = TIME * speed * 6.0;
	vec2 warp = vec2(fbm(p + vec2(t, 3.1)), fbm(p + vec2(-2.7, t * 0.8)));
	float a = fbm(p * 0.9 + warp * 1.6 + vec2(t, t * 0.35));
	float b = fbm(p * 0.5 - warp * 1.2 + vec2(-t * 0.7, t * 0.25) + 11.0);
	float n = a * 0.6 + b * 0.4;
	float banks = smoothstep(0.38 - softness * 0.4, 0.72 + softness * 0.3, n);
	float f = 0.18 + 0.82 * banks;
	// fade the edges of the sprite so its border is never a visible line
	vec2 e = min(UV, 1.0 - UV);
	f *= smoothstep(0.0, 0.08, min(e.x, e.y));
	COLOR = vec4(fog_color.rgb, f * density);
}
