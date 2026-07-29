shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Procedural animated flame drawn on a quad. Cylindrically billboarded so
// candle and hearth flames read from any angle. Used by the fireplace,
// candles, and the kitchen stove.

uniform float intensity: hint_range(0.2, 3.0) = 1.0;
uniform float flame_speed: hint_range(0.2, 5.0) = 1.7;
uniform float turbulence: hint_range(0.0, 1.0) = 0.45;
uniform vec3 core_color: source_color = vec3(1.0, 0.85, 0.35);
uniform vec3 body_color: source_color = vec3(1.0, 0.42, 0.06);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p = p * 2.1 + vec2(13.7, 7.3);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	// Cylindrical billboard: face the camera around the Y axis only.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	// UV space: x in [-1, 1] across the flame, y = 0 at base, 1 at tip.
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);

	// Upward-scrolling turbulence bends the flame sides.
	float wobble = fbm(vec2(uv.x * 2.5, uv.y * 3.0 - TIME * flame_speed));
	uv.x += (wobble - 0.5) * turbulence * uv.y;

	// Flame silhouette: wide at the base, tapering to the tip.
	float width = mix(0.75, 0.05, smoothstep(0.0, 1.0, uv.y));
	float body = 1.0 - smoothstep(width * 0.35, width, abs(uv.x));
	body *= smoothstep(0.0, 0.12, uv.y) * (1.0 - smoothstep(0.55, 1.0, uv.y));

	float core = 1.0 - smoothstep(0.0, width * 0.45, abs(uv.x));
	core *= 1.0 - smoothstep(0.05, 0.55, uv.y);

	vec3 color = mix(body_color, core_color, clamp(core, 0.0, 1.0));
	float strength = clamp(body, 0.0, 1.0) * intensity;
	ALBEDO = color * strength;
	ALPHA = strength;
}
