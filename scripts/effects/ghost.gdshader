shader_type canvas_item;
render_mode unshaded;
// A ghost: the sprite turned pale blue and translucent, rippling, and dissolving toward the feet into a tail.
// Unshaded, so it still glows in a blackout. `hurt` works like in hurt_flash.gdshader.
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float opacity = 0.72;
uniform float fade_start = 0.5;  // fraction of the sprite's height where the body starts to dissolve

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * 6.0 + UV.y * 14.0) * 0.012 * (0.4 + UV.y);
	vec4 c = texture(TEXTURE, uv);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ghost = mix(vec3(lum), tint.rgb, 0.7) * 1.25 + 0.08;
	ghost = mix(ghost, vec3(1.0, 0.35, 0.35), hurt * 0.55);
	float body = 1.0 - smoothstep(fade_start, 1.0, UV.y);
	COLOR = vec4(ghost, c.a * opacity * mix(0.2, 1.0, body));
}
