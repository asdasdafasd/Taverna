shader_type spatial;
render_mode unshaded, cull_front;

// Warm pulsing rim outline drawn as a material overlay on focused
// interactables. Renders backfaces pushed out along normals so the
// silhouette reads as a clean border around the object.

uniform vec4 outline_color: source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float outline_width: hint_range(0.005, 0.08) = 0.02;
uniform float pulse_speed: hint_range(0.0, 8.0) = 3.0;
uniform float pulse_amount: hint_range(0.0, 1.0) = 0.25;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	float pulse = 1.0 - pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	ALBEDO = outline_color.rgb * pulse;
}
