extends Node2D

var _size := Vector2.ZERO
var _color := Color.WHITE


func set_part(size: Vector2, color: Color) -> void:
	_size = size
	_color = color
	queue_redraw()


func _draw() -> void:
	if _size == Vector2.ZERO:
		return

	draw_rect(Rect2(Vector2.ZERO, _size), _color)
