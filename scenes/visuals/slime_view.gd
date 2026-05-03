extends "res://scenes/visuals/entity_base.gd"

var _radius := 0.0


func get_visual_size() -> Vector2:
	return Vector2(_radius * 2.0, _radius * 2.0)


func _on_entity_updated(entity_state: Dictionary) -> void:
	var spec: Dictionary = entity_state.get(&"spec", {})
	_radius = float(spec.get(&"radius", 0.0))
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	draw_circle(Vector2(_radius, _radius), _radius, Color.MEDIUM_SEA_GREEN)
