shader_type canvas_item;
// Damage flash for sprites without other effects: tints toward red by `hurt` (0..1).
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
// Per-sprite colour variety (the defaults change nothing): hue, saturation and brightness.
uniform float hue = 0.0;  // radians
uniform float sat = 1.0;
uniform vec3 tint = vec3(1.0);

vec3 hue_rotate(vec3 c, float a) {
	float cs = cos(a);
	float sn = sin(a);
	vec3 r1 = vec3(0.299 + 0.701 * cs + 0.168 * sn, 0.587 - 0.587 * cs + 0.330 * sn, 0.114 - 0.114 * cs - 0.497 * sn);
	vec3 r2 = vec3(0.299 - 0.299 * cs - 0.328 * sn, 0.587 + 0.413 * cs + 0.035 * sn, 0.114 - 0.114 * cs + 0.292 * sn);
	vec3 r3 = vec3(0.299 - 0.300 * cs + 1.250 * sn, 0.587 - 0.588 * cs - 1.050 * sn, 0.114 + 0.886 * cs - 0.203 * sn);
	return clamp(vec3(dot(r1, c), dot(r2, c), dot(r3, c)), 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = hue_rotate(c.rgb, hue);
	float l = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(l), rgb, sat) * tint;
	rgb = mix(rgb, vec3(rgb.r * 0.6 + 0.55, rgb.g * 0.35, rgb.b * 0.35), hurt * 0.55);
	COLOR = vec4(rgb, c.a);
}
