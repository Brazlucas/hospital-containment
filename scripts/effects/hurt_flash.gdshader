shader_type canvas_item;
// Damage flash for sprites without other effects: tints toward red by `hurt` (0..1).
uniform float hurt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(c.r * 0.6 + 0.55, c.g * 0.35, c.b * 0.35), hurt * 0.55);
	COLOR = c;
}
