extends Node2D

const COLOR := Color(1.0, 0.15, 0.15, 0.85)
const RADIUS := 9.0
const LINE_WIDTH := 2.0


func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, COLOR, LINE_WIDTH)
	draw_line(Vector2(-RADIUS, 0.0), Vector2(RADIUS, 0.0), COLOR, LINE_WIDTH)
	draw_line(Vector2(0.0, -RADIUS), Vector2(0.0, RADIUS), COLOR, LINE_WIDTH)
