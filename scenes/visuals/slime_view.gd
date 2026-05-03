extends "res://scenes/visuals/entity_base.gd"

const BOUNCE_AMOUNT := 0.25

var _radius := 0.0
var _squeeze := 0.0


func get_visual_size() -> Vector2:
	return Vector2(_radius * 2.0, _radius * 2.0)


func _on_entity_updated(entity_state: Dictionary) -> void:
	var spec: Dictionary = entity_state.get(&"spec", {})
	_radius = float(spec.get(&"radius", 0.0))
	queue_redraw()


func _set_move_pose(direction: float) -> void:
	_squeeze = abs(direction) * BOUNCE_AMOUNT
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	# Anchor squash/stretch at the bottom-center so the slime appears to bounce on the ground.
	# draw_set_transform origin = bottom-center (radius, radius*2), scale = squash axes.
	# draw_circle at (0, -radius) relative to that origin keeps the bottom at y=2*radius.
	draw_set_transform(Vector2(_radius, _radius * 2.0), 0.0, Vector2(1.0 + _squeeze, 1.0 - _squeeze))
	draw_circle(Vector2(0.0, -_radius), _radius, Color.MEDIUM_SEA_GREEN)
	draw_set_transform(Vector2.ZERO)
