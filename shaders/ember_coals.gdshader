shader_type spatial;

// Glowing coal bed for the hearth. Scrolling noise drives slow pulsing
// embers that brighten in the cracks between dark charcoal chunks.

uniform float glow_strength: hint_range(0.0, 6.0) = 2.2;
uniform float pulse_speed: hint_range(0.0, 3.0) = 0.6;
uniform vec3 coal_color: source_color = vec3(0.05, 0.03, 0.03);
uniform vec3 ember_color: source_color = vec3(1.0, 0.32, 0.05);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.7);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 p = UV * 7.0;
	float chunks = value_noise(p);
	float cracks = smoothstep(0.42, 0.62, chunks);
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed * 6.28 + chunks * 12.0);
	ALBEDO = coal_color;
	ROUGHNESS = 0.9;
	EMISSION = ember_color * cracks * pulse * glow_strength;
}
