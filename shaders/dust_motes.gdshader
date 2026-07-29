shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Floating dust motes rendered on stacked translucent quads. Each quad
// carries a field of drifting soft dots that fade in and out, selling the
// warm hazy air of the tavern near windows and the fireplace.

uniform float density: hint_range(2.0, 24.0) = 10.0;
uniform float mote_size: hint_range(0.005, 0.08) = 0.025;
uniform float drift_speed: hint_range(0.0, 0.5) = 0.06;
uniform float brightness: hint_range(0.0, 2.0) = 0.5;
uniform vec3 mote_color: source_color = vec3(1.0, 0.85, 0.6);

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void fragment() {
	vec2 grid_uv = UV * density;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv);
	float glow = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = hash22(cell + offset);
			// Per-mote drifting position inside its cell.
			vec2 mote_pos = offset + 0.5 + 0.4 * vec2(
				sin(TIME * drift_speed * 6.28 + seed.x * 6.28),
				cos(TIME * drift_speed * 4.71 + seed.y * 6.28)
			);
			float dist = length(local - mote_pos);
			float twinkle = 0.5 + 0.5 * sin(TIME * (0.4 + seed.x) + seed.y * 6.28);
			glow += smoothstep(mote_size * density, 0.0, dist) * twinkle;
		}
	}
	// Fade near quad edges so the volume has no hard borders.
	vec2 edge = smoothstep(0.0, 0.15, UV) * smoothstep(1.0, 0.85, UV);
	float mask = edge.x * edge.y;
	vec3 color = mote_color * glow * brightness * mask;
	ALBEDO = color;
	ALPHA = clamp(glow * brightness, 0.0, 1.0) * mask;
}
