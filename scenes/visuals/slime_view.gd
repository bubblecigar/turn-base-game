extends "res://scenes/visuals/entity_base.gd"

const BOUNCE_AMOUNT := 0.25
const ATTACK_ANIMATION_SECONDS := 0.34
const ATTACK_ANIMATION_NAME := &"slime_attack"
const ATTACK_SQUEEZE_AMOUNT := 0.38

var _radius := 0.0
var _squeeze := 0.0
var _attack_squeeze := 0.0
var _attack_tween: Tween
var _attack_animation_id := &""


func get_visual_size() -> Vector2:
	return Vector2(_radius * 2.0, _radius * 2.0)


func _on_entity_updated(entity_state: Dictionary) -> void:
	var spec: Dictionary = entity_state.get(&"spec", {})
	_radius = float(spec.get(&"radius", 0.0))
	queue_redraw()


func _set_move_pose(direction: float) -> void:
	_squeeze = abs(direction) * BOUNCE_AMOUNT
	queue_redraw()


func _play_attack_performed_visual(_args: Dictionary) -> void:
	if animation_tracker == null:
		return

	if _attack_tween:
		_attack_tween.kill()
		_consume_active_attack_animation()

	var animation_id: StringName = animation_tracker.register_animation(ATTACK_ANIMATION_NAME)
	_attack_animation_id = animation_id
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_QUAD)
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.tween_method(_set_attack_squeeze, 0.0, ATTACK_SQUEEZE_AMOUNT, ATTACK_ANIMATION_SECONDS * 0.35)
	_attack_tween.tween_method(_set_attack_squeeze, ATTACK_SQUEEZE_AMOUNT, 0.0, ATTACK_ANIMATION_SECONDS * 0.65)
	_attack_tween.finished.connect(_on_attack_tween_finished.bind(animation_id))


func _set_attack_squeeze(next_squeeze: float) -> void:
	_attack_squeeze = next_squeeze
	queue_redraw()


func _on_attack_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _attack_animation_id == animation_id:
		_attack_animation_id = &""
		_attack_tween = null
		_set_attack_squeeze(0.0)


func _consume_active_attack_animation() -> void:
	if _attack_animation_id == &"":
		return

	animation_tracker.consume_animation(_attack_animation_id)
	_attack_animation_id = &""
	_set_attack_squeeze(0.0)


func _draw() -> void:
	if _radius <= 0.0:
		return

	var total_squeeze = max(_squeeze, _attack_squeeze)
	# Anchor squash/stretch at the bottom-center so the slime appears to bounce on the ground.
	# draw_set_transform origin = bottom-center (radius, radius*2), scale = squash axes.
	# draw_circle at (0, -radius) relative to that origin keeps the bottom at y=2*radius.
	draw_set_transform(Vector2(_radius, _radius * 2.0), 0.0, Vector2(1.0 + total_squeeze, 1.0 - total_squeeze))
	draw_circle(Vector2(0.0, -_radius), _radius, Color.MEDIUM_SEA_GREEN)
	draw_set_transform(Vector2.ZERO)
