shader_type canvas_item;
// Pixel-art floor reflection, applied to a vertically flipped copy of a sprite (see Reflector).
//  - only where the floor map says there is floor (R), so it never spills over walls and furniture
//  - subtle on dry floor, strong and rippling on wet floor, puddles and blood (G)
//  - fades with distance from the feet in a few hard bands (pixel-art style)
//  - desaturated, cooled and posterized so it reads as pixel art, not as a soft copy

uniform sampler2D refl_map : filter_linear, repeat_disable;  // R = floor, G = wetness (see ReflectionMap)
uniform vec2 map_origin = vec2(0.0);          // world px of the map's top-left corner
uniform vec2 map_size = vec2(640.0, 480.0);   // world px the map covers
uniform float alpha_dry : hint_range(0.0, 1.0) = 0.22;
uniform float alpha_wet : hint_range(0.0, 1.0) = 0.5;
uniform float fade_dry = 26.0;                // source px below the feet until a dry reflection is gone
uniform float fade_wet = 46.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 muv = (world_pos - map_origin) / map_size;
	if (muv.x < 0.0 || muv.y < 0.0 || muv.x >= 1.0 || muv.y >= 1.0) discard;
	vec4 m = texture(refl_map, muv);
	if (m.r < 0.5) discard;
	float wet = m.g;

	// distance below the feet, in source pixels (UV.y = 1 at the object's feet of the flipped copy)
	float depth = (1.0 - UV.y) / TEXTURE_PIXEL_SIZE.y;
	float fade = exp(-depth / mix(fade_dry, fade_wet, wet));

	// whole-pixel ripple on wet floor
	float shift = floor(sin(world_pos.y * 0.9 + TIME * 2.2) * 1.2 * wet + 0.5);
	vec4 tex = texture(TEXTURE, UV + vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0));
	if (tex.a < 0.05) discard;

	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(lum), tex.rgb, 0.8) * vec3(0.9, 0.97, 1.0);
	col *= 0.7;  // a reflection is darker than the object, most of all in a dark room
	col = floor(col * 10.0 + 0.5) / 10.0;
	float a = tex.a * mix(alpha_dry, alpha_wet, smoothstep(0.0, 0.6, wet)) * fade;
	a = floor(a * 5.0 + 0.5) / 5.0;  // hard alpha bands
	if (a < 0.1) discard;
	COLOR = vec4(col, a);
}
