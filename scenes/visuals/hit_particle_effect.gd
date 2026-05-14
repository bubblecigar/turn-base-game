extends Node2D

@export var particle_count := 28
@export var particle_size := 4.0
@export var min_distance := 28.0
@export var max_distance := 96.0
@export var duration := 0.55
@export var spread_degrees := 175.0
@export var color := Color(1.0, 0.24, 0.08, 1.0)
@export var highlight_color := Color(1.0, 0.9, 0.22, 1.0)

var _direction := Vector2.RIGHT
var _started := false


func set_hit_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO and direction != Vector2.INF:
		_direction = direction.normalized()


func start(direction: Vector2 = Vector2.RIGHT) -> void:
	if _started:
		return

	_started = true
	set_hit_direction(direction)
	_emit_particles()


func _ready() -> void:
	start(_direction)


func _emit_particles() -> void:
	for i in particle_count:
		var particle := Polygon2D.new()
		var size := randf_range(particle_size * 0.45, particle_size * 1.35)
		particle.polygon = PackedVector2Array([
			Vector2(0.0, -size * 1.45),
			Vector2(size * 0.85, 0.0),
			Vector2(0.0, size * 1.45),
			Vector2(-size * 0.85, 0.0),
		])
		particle.color = highlight_color if i % 3 == 0 else color
		particle.rotation = randf() * TAU
		particle.scale = Vector2.ONE * randf_range(0.8, 1.45)
		add_child(particle)

		var angle_offset := deg_to_rad(randf_range(-spread_degrees * 0.5, spread_degrees * 0.5))
		var travel_direction := _direction.rotated(angle_offset)
		var travel_distance := randf_range(min_distance, max_distance)
		var travel := travel_direction * travel_distance
		var particle_duration := randf_range(duration * 0.7, duration * 1.15)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", travel, particle_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "rotation", particle.rotation + randf_range(-TAU * 1.5, TAU * 1.5), particle_duration)
		tween.tween_property(particle, "scale", Vector2.ZERO, particle_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "modulate:a", 0.0, particle_duration)

	get_tree().create_timer(duration * 1.2).timeout.connect(queue_free)
