shader_type canvas_item;
// Screen-space rain, fast and heavy. Three layers (far, middle, near) of long thin streaks that fall across the whole
// screen at 1000 to 3000 pixels per second. Streaks are born at random along each slanted column, so nothing repeats
// or lines up. `intensity` (0..1) fades the rain in and out and thins it out.
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint : source_color = vec3(0.7, 0.8, 0.95);
uniform float slant = 0.2;  // sideways pixels per pixel fallen (the wind)

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// colw = column width and period = distance between streaks of one column, both in physical pixels.
// speed = periods fallen per second, len = streak length as a fraction of the period.
float layer(vec2 p, float colw, float period, float speed, float len, float width, float density, float seed) {
	float xs = p.x - slant * p.y;  // in these coordinates every streak is a vertical line
	float c = floor(xs / colw);
	float phase = hash21(vec2(c, seed));
	float pace = 0.85 + 0.3 * hash21(vec2(c, seed + 17.3));
	float y = p.y / period - TIME * speed * pace - phase;
	float k = floor(y);
	float fy = fract(y);  // 0 at the top of the streak's tail, len at its head
	if (fy > len) {
		return 0.0;
	}
	if (hash21(vec2(c + k * 13.7, seed + 3.1)) > density * intensity) {
		return 0.0;
	}
	float x0 = 0.1 + 0.8 * hash21(vec2(c + k * 3.1, seed + 5.9));
	float dx = (fract(xs / colw) - x0) * colw;
	return smoothstep(width, 0.0, abs(dx)) * pow(fy / len, 1.3);
}

void fragment() {
	vec2 p = SCREEN_UV / SCREEN_PIXEL_SIZE;  // physical pixels
	float a = layer(p, 20.0, 420.0, 2.6, 0.22, 0.8, 0.7, 1.0) * 0.30;
	a += layer(p, 30.0, 560.0, 3.2, 0.26, 1.1, 0.55, 7.0) * 0.45;
	a += layer(p, 50.0, 700.0, 4.0, 0.30, 1.6, 0.4, 13.0) * 0.65;
	COLOR = vec4(tint, clamp(a, 0.0, 0.85));
}
