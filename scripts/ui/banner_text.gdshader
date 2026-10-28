shader_type canvas_item;
// Animated lettering for the HUD banners: the letters ride a wave, a band of the accent colour sweeps along the
// word, and the whole thing throbs a little. The outline (dark) is left alone so the word keeps its edge.
uniform vec4 accent : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float wave_amp = 1.6;

varying float along;

void vertex() {
	along = VERTEX.x;
	VERTEX.y += sin(TIME * 7.0 + VERTEX.x * 0.22) * wave_amp;
}

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float body = smoothstep(0.12, 0.4, lum);  // 0 on the black outline
	float band = pow(0.5 + 0.5 * sin(along * 0.045 - TIME * 5.5), 2.0);
	float throb = 0.85 + 0.15 * sin(TIME * 11.0);
	vec3 c = mix(COLOR.rgb, accent.rgb, band * 0.9 * body);
	COLOR.rgb = c * mix(1.0, throb + 0.25, body);
}
