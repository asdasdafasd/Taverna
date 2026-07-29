class_name Crosshair
extends Control
## Minimal centered crosshair: a dot with four short ticks, drawn in code so
## it needs no texture assets and scales cleanly.

const DOT_RADIUS: float = 1.6
const TICK_LENGTH: float = 5.0
const TICK_GAP: float = 4.0
const TICK_WIDTH: float = 1.6


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, DOT_RADIUS, Color.WHITE)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(
			center + direction * TICK_GAP,
			center + direction * (TICK_GAP + TICK_LENGTH),
			Color.WHITE,
			TICK_WIDTH,
			true
		)
