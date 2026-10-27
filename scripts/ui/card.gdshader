shader_type canvas_item;
// Collectible-card shader for the level-up choices (Balatro style). It is applied to a TextureRect that shows
// the card's face (rendered in a SubViewport, see upgrade_card.gd) and does two things:
//  1. tilts the flat card in perspective toward the pointer, by working out which point of the card is seen at
//     each pixel, so the text and the border tilt with it;
//  2. adds the rarity's effect on top: 0 brushed steel, 1 foil, 2 holographic, 3 polychrome, 4 gold. The effects tint the card's
//     dark areas and barely touch the bright text, so it stays readable.

uniform int rarity : hint_range(0, 4) = 0;
uniform vec2 tilt = vec2(0.0);                    // -1..1: where the pointer is relative to the card's centre
uniform float lift : hint_range(0.0, 1.0) = 0.0;  // 1 while hovered or focused: stronger effects
uniform float seed = 0.0;                         // so two cards of one rarity do not shimmer in lockstep
uniform vec2 size = vec2(134.0, 174.0);           // px of the quad this shader draws on
uniform float focal = 280.0;                      // camera distance in px: smaller = stronger perspective

const float MAX_ANGLE = 0.3;                      // radians of tilt at |tilt| = 1

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

// Twinkling four-point stars on a 6 px grid.
float sparkle(vec2 uv) {
	vec2 cell = uv * size / 6.0;
	float h = hash(floor(cell) + seed);
	float twinkle = pow(max(0.0, sin(TIME * 4.0 + h * 40.0)), 20.0);
	vec2 f = fract(cell) - 0.5;
	float star = max(0.0, 1.0 - 7.0 * min(abs(f.x), abs(f.y))) * max(0.0, 1.0 - 1.8 * length(f));
	return step(0.9, h) * twinkle * star;
}

void fragment() {
	// ---- perspective: the point of the flat card that is seen at this pixel
	vec2 ang = vec2(-tilt.y, tilt.x) * MAX_ANGLE;   // the card faces the pointer
	mat3 R = rot_y(ang.y) * rot_x(ang.x);
	vec3 n = R * vec3(0.0, 0.0, 1.0);
	vec2 p = (UV - 0.5) * size;
	float t = focal * n.z / (n.x * p.x + n.y * p.y + n.z * focal);
	vec3 hit = vec3(t * p.x, t * p.y, focal * (t - 1.0));
	vec3 q = rot_x(-ang.x) * (rot_y(-ang.y) * hit);
	vec2 uv = q.xy / size + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}

	vec4 base = texture(TEXTURE, uv);
	vec2 px = 1.0 / size;
	// 1 on the card's rim (within ~3 px of its silhouette), 0 inside
	float inner = min(
		min(texture(TEXTURE, uv + vec2(px.x * 3.0, 0.0)).a, texture(TEXTURE, uv - vec2(px.x * 3.0, 0.0)).a),
		min(texture(TEXTURE, uv + vec2(0.0, px.y * 3.0)).a, texture(TEXTURE, uv - vec2(0.0, px.y * 3.0)).a));
	float edge = base.a * (1.0 - inner);
	float shadow = texture(TEXTURE, uv - vec2(3.0, 5.0) * px).a;

	vec3 col = base.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float dark = 1.0 - smoothstep(0.22, 0.55, luma);    // 1 on the dark background, 0 on bright text
	float k = 1.0 + 0.45 * lift;
	float lean = tilt.x * 0.8 + tilt.y * 0.5;           // moves every effect as the card tilts

	if (rarity == 1) {
		// FOIL: a silvery band slides across the card, with grain glints inside it
		float diag = uv.x * 0.8 + uv.y * 0.6;
		float s = fract(diag - lean * 0.9 + TIME * 0.12 + seed);
		float band = smoothstep(0.0, 0.07, s) * (1.0 - smoothstep(0.07, 0.3, s));
		vec3 foil = vec3(0.72, 0.86, 1.0);
		col += foil * band * (0.18 + 0.4 * dark) * k;
		float grain = step(0.97, hash(floor(uv * size * 0.5) + floor(TIME * 8.0))) * band;
		col += foil * grain * 0.5;
		col = mix(col, foil, edge * (0.5 + 0.2 * lift));
	} else if (rarity == 2) {
		// HOLOGRAPHIC: a rainbow that shifts with the viewing angle, over fine diagonal lines
		float h = fract(uv.x * 0.9 + uv.y * 0.6 + lean + 0.08 * sin(uv.y * 9.0 + TIME * 1.5) + seed);
		vec3 rb = hsv2rgb(vec3(h, 0.7, 1.0));
		float lines = 0.5 + 0.5 * sin((uv.x * 0.7 + uv.y) * 70.0 + TIME * 2.0);
		col = mix(col, col * 0.5 + rb * 0.7, (0.03 + 0.2 * dark) * k);
		col += rb * lines * 0.05 * dark * k;
		col = mix(col, rb, edge * 0.85);
	} else if (rarity == 3) {
		// POLYCHROME: the whole card's colours rotate around the wheel, with a travelling glare and sparkles
		vec3 hsv = rgb2hsv(col);
		hsv.x = fract(hsv.x + uv.x * 0.6 + uv.y * 0.35 + TIME * 0.15 + lean * 0.5 + seed);
		hsv.y = clamp(hsv.y * 1.3 + 0.35 * dark, 0.0, 1.0);
		hsv.z = clamp(hsv.z * 1.1 + 0.1 * dark * k, 0.0, 1.0);
		col = mix(col, hsv2rgb(hsv), 0.1 + 0.9 * dark);   // bright text keeps its own colour (green = good, red = bad)
		float glare = max(0.0, 1.0 - abs(fract(uv.x * 0.9 - uv.y * 0.5 + TIME * 0.2 + lean * 0.6) - 0.5) * 5.0);
		col += vec3(1.0, 0.92, 1.0) * glare * 0.18 * dark * k;
		float pulse = 0.5 + 0.5 * sin(TIME * 3.0);
		col = mix(col, hsv2rgb(vec3(fract(TIME * 0.25 + uv.y * 0.8), 0.85, 1.0)), edge * (0.65 + 0.3 * pulse));
		col += vec3(1.0, 0.95, 1.0) * sparkle(uv) * 0.9 * base.a;
	} else if (rarity == 4) {
		// GOLD: molten gold flames rise from the bottom, sparks drift up, and the rim pulses
		float flame_noise = vnoise(uv * vec2(5.0, 8.0) + vec2(seed, -TIME * 0.7));
		float flame = smoothstep(0.3, 0.95, flame_noise * (0.35 + uv.y * 0.9));
		vec3 gold = mix(vec3(0.85, 0.4, 0.04), vec3(1.0, 0.9, 0.45), flame);
		col += gold * (0.07 + 0.33 * flame) * dark * k;
		vec2 cell = vec2(uv.x * 20.0, uv.y * 28.0 + TIME * 7.0);
		float spark = step(0.975, hash(floor(cell) + seed)) * (1.0 - length(fract(cell) - 0.5) * 1.6);
		col += vec3(1.0, 0.82, 0.35) * max(spark, 0.0) * 0.9 * base.a;
		col = mix(col, vec3(1.0, 0.82, 0.3), edge * (0.65 + 0.35 * sin(TIME * 4.0)));
	} else {
		// COMMON: brushed steel. Faint horizontal streaks, a soft sheen that follows the tilt, a lighter top
		// and a bright rim, so even the plainest card catches the light.
		float streak = vnoise(vec2(uv.x * 4.0, uv.y * 110.0 + seed));
		float sheen = exp(-pow(uv.x * 0.7 + uv.y * 0.5 - (0.5 + lean * 0.45 + 0.08 * sin(TIME * 0.7 + seed)), 2.0) * 16.0);
		col *= 0.88 + 0.3 * (1.0 - uv.y);
		col += vec3(0.78, 0.84, 0.9) * (sheen * 0.2 + (streak - 0.5) * 0.07) * (0.45 + 0.55 * dark) * (1.0 + 0.8 * lift);
		col = mix(col, vec3(0.8, 0.86, 0.92), edge * (0.4 + 0.25 * lift));
	}

	float a = base.a;
	if (a < 0.01) {
		col = vec3(0.0);
		a = shadow * 0.4;
	}
	COLOR = vec4(col, a);
}
