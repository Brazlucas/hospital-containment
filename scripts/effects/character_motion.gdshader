shader_type canvas_item;
// Subtle life for single-frame character art: breathing, hair sway,
// hair lag opposite to movement, and alternating foot lift when walking.
// Zones are fractions of the frame height (96x112 frames).

uniform float breath : hint_range(0.0, 0.1) = 0.02;
uniform float hair_sway : hint_range(0.0, 0.1) = 0.01;
uniform float hair_lag = 0.0;       // uv.x shift, opposite to movement
uniform float step_phase = 0.0;
uniform float step_lift : hint_range(0.0, 0.1) = 0.0;
uniform float speed = 1.0;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;  // 0 = normal, 1 = full red tint (damage flash)

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Torso breathing: widen chest/shoulders a touch, in sync with a slow sine.
	float torso = smoothstep(0.3, 0.45, uv.y) * (1.0 - smoothstep(0.6, 0.75, uv.y));
	float b = sin(t * 1.7) * 0.5 + 0.5;
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 + breath * b * torso);
	// Chest rises: sample slightly lower so the content moves up.
	uv.y += breath * 0.25 * b * torso;

	// Hair: sways more toward the tips (lower), with a lag opposite movement.
	float hair = smoothstep(0.22, 0.6, uv.y) * (1.0 - smoothstep(0.62, 0.78, uv.y));
	float side = abs(uv.x - 0.5) * 2.0;  // only the outer strands move much
	uv.x += (sin(t * 1.3 + uv.y * 9.0) * hair_sway + hair_lag) * hair * (0.4 + side);

	// Feet: alternate lift (left half vs right half).
	float feet = smoothstep(0.86, 0.94, uv.y);
	float left = step(uv.x, 0.5);
	float lift = mix(max(-sin(step_phase), 0.0), max(sin(step_phase), 0.0), left);
	uv.y += step_lift * lift * feet;

	vec4 c = texture(TEXTURE, uv);
	c.rgb = mix(c.rgb, vec3(c.r * 0.6 + 0.55, c.g * 0.35, c.b * 0.35), hurt * 0.55);
	COLOR = c;
}
