shader_type canvas_item;
// Rain on the camera lens: the whole screen is a little blurred (a wet lens), and drops bead up on it, slide down a
// bit and fade. Each drop is a tiny lens: inside it the scene is sharp, shifted and upside down, with a bright
// highlight. Two sizes of drops. `wetness` (0..1) fades the effect in and out.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float wetness : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// x,y = how far to shift the screen lookup inside the drop, z = how much of the pixel is drop, w = highlight
vec4 drops(vec2 p, vec2 res, float cell, float r_min, float r_max, float density, float seed, float cycle) {
	vec2 c = floor(p / cell);
	vec2 f = fract(p / cell);
	float r1 = hash21(c + seed);
	float r2 = hash21(c + seed + 11.1);
	float r3 = hash21(c + seed + 23.7);
	float r4 = hash21(c + seed + 37.3);
	float r5 = hash21(c + seed + 51.9);
	if (r5 > density * wetness) {
		return vec4(0.0);
	}
	float life = fract(TIME / cycle + r1);
	float grow = smoothstep(0.0, 0.1, life) * (1.0 - smoothstep(0.8, 1.0, life));
	float radius = mix(r_min, r_max, r2) * grow;
	if (radius < 0.6) {
		return vec4(0.0);
	}
	vec2 center = vec2(0.2 + 0.6 * r3, 0.2 + 0.35 * r4 + life * 0.25) * cell;  // it creeps down while it lives
	vec2 d = f * cell - center;
	d.y *= 0.9;  // a hair taller than wide
	float dist = length(d);
	float mask = smoothstep(radius, radius * 0.78, dist);
	vec2 n = d / radius;
	float spec = pow(max(0.0, 1.0 - length(n - vec2(-0.4, -0.45))), 3.0);
	return vec4(-d / res * 1.9, mask, spec);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * res;
	vec3 col = textureLod(screen_tex, SCREEN_UV, 0.4 * wetness).rgb;  // the wet lens blurs everything just a touch
	vec4 big = drops(p, res, 54.0, 3.5, 10.0, 0.3, 3.0, 13.0);
	vec4 small = drops(p + 137.0, res, 30.0, 1.6, 4.5, 0.45, 9.0, 8.0);
	vec4 d = big.z >= small.z ? big : small;
	if (d.z > 0.0) {
		vec3 sharp = textureLod(screen_tex, SCREEN_UV + d.xy, 0.0).rgb;
		col = mix(col, sharp * 1.25, d.z);
		col += vec3(0.8, 0.9, 1.0) * d.w * d.z * 0.4;
		col *= 1.0 - 0.25 * d.z * (1.0 - smoothstep(0.0, 0.4, d.w));  // a darker rim around the drop
	}
	col = mix(col, col * vec3(0.92, 0.98, 1.05), 0.3 * wetness);  // a faint cold, damp cast
	COLOR = vec4(col, 1.0);
}
