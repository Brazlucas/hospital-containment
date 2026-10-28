shader_type canvas_item;
// Pain: what the screen does when the player is hit. Red vignette, colour fringing, sideways-torn glitch bands,
// grain and scanlines, all scaled by `pain` (0..1, decays after the hit).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pain : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 26.0);
	float r = hash(vec2(band, seed));
	float torn = step(0.8, r) * (r - 0.9) * 0.14 * pain;  // a few strips slide sideways
	uv.x += torn;
	float ca = 0.012 * pain;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	float vig = smoothstep(0.25, 0.8, length(SCREEN_UV - 0.5) * 1.25);
	col = mix(col, vec3(0.75, 0.02, 0.06), vig * 0.6 * pain);
	col += (hash(SCREEN_UV * vec2(480.0, 270.0) + seed) - 0.5) * 0.3 * pain;
	col *= 1.0 - 0.2 * pain * step(0.5, fract(SCREEN_UV.y * 135.0));
	COLOR = vec4(col, 1.0);
}
