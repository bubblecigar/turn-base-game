extends "res://scenes/visuals/entity_base.gd"

const DRAW_SCALE := 1.0
const WALK_ARM_SWING_DEGREES := 12.0
const WALK_LEG_SWING_DEGREES := 10.0
const ATTACK_ANIMATION_SECONDS := 0.32
const ATTACK_ANIMATION_NAME := &"character_attack"
const ATTACK_ARM_SWING_DEGREES := 58.0
const ATTACK_BODY_LEAN_DEGREES := 6.0

var _character_size := Vector2.ZERO
var _attack_tween: Tween
var _attack_animation_id := &""

@onready var head: Node2D = $Head
@onready var neck: Node2D = $Neck
@onready var body: Node2D = $Body
@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm
@onready var left_leg: Node2D = $LeftLeg
@onready var right_leg: Node2D = $RightLeg


func get_visual_size() -> Vector2:
	return _character_size


func _on_entity_updated(entity_state: Dictionary) -> void:
	_update_parts(entity_state)


func _set_move_pose(direction: float) -> void:
	left_arm.rotation_degrees = WALK_ARM_SWING_DEGREES * direction
	right_arm.rotation_degrees = -WALK_ARM_SWING_DEGREES * direction
	left_leg.rotation_degrees = -WALK_LEG_SWING_DEGREES * direction
	right_leg.rotation_degrees = WALK_LEG_SWING_DEGREES * direction


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
	_attack_tween.set_parallel(true)
	_attack_tween.tween_property(body, "rotation_degrees", -ATTACK_BODY_LEAN_DEGREES, ATTACK_ANIMATION_SECONDS * 0.35)
	_attack_tween.tween_property(left_arm, "rotation_degrees", ATTACK_ARM_SWING_DEGREES, ATTACK_ANIMATION_SECONDS * 0.35)
	_attack_tween.tween_property(right_arm, "rotation_degrees", -ATTACK_ARM_SWING_DEGREES, ATTACK_ANIMATION_SECONDS * 0.35)
	_attack_tween.chain().tween_property(body, "rotation_degrees", 0.0, ATTACK_ANIMATION_SECONDS * 0.65)
	_attack_tween.parallel().tween_property(left_arm, "rotation_degrees", 0.0, ATTACK_ANIMATION_SECONDS * 0.65)
	_attack_tween.parallel().tween_property(right_arm, "rotation_degrees", 0.0, ATTACK_ANIMATION_SECONDS * 0.65)
	_attack_tween.finished.connect(_on_attack_tween_finished.bind(animation_id))


func _on_attack_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _attack_animation_id == animation_id:
		_attack_animation_id = &""
		_attack_tween = null
		body.rotation_degrees = 0.0
		_set_move_pose(0.0)


func _consume_active_attack_animation() -> void:
	if _attack_animation_id == &"":
		return

	animation_tracker.consume_animation(_attack_animation_id)
	_attack_animation_id = &""


func _update_parts(entity_state: Dictionary) -> void:
	var character_spec: Dictionary = entity_state.get(&"spec", {})
	if character_spec.is_empty():
		return

	var head_size := _get_head_size(character_spec.get("head", {}))
	var neck_size := _get_part_size(character_spec.get("neck", {}))
	var body_size := _get_part_size(character_spec.get("body", {}))
	var arm_size := _get_part_size(character_spec.get("arms", {}))
	var leg_size := _get_part_size(character_spec.get("legs", {}))
	var width = max(
		body_size.x + arm_size.x * 2.0,
		head_size.x,
		neck_size.x,
		leg_size.x * 2.0
	)
	_character_size = Vector2(width, head_size.y + neck_size.y + body_size.y + leg_size.y)

	head.position = Vector2((width - head_size.x) / 2.0, 0.0)
	neck.position = Vector2((width - neck_size.x) / 2.0, head_size.y)
	body.position = Vector2((width - body_size.x) / 2.0, head_size.y + neck_size.y)
	left_arm.position = Vector2(0.0, body.position.y + body_size.y * 0.05)
	right_arm.position = Vector2(width - arm_size.x, body.position.y + body_size.y * 0.05)
	left_leg.position = Vector2(width * 0.25, body.position.y + body_size.y)
	right_leg.position = Vector2(width * 0.53, body.position.y + body_size.y)

	head.set_part(head_size, Color.CORNFLOWER_BLUE)
	neck.set_part(neck_size, Color.LIGHT_SKY_BLUE)
	body.set_part(body_size, Color.SEA_GREEN)
	left_arm.set_part(arm_size, Color.GOLDENROD)
	right_arm.set_part(arm_size, Color.GOLDENROD)
	left_leg.set_part(leg_size, Color.INDIAN_RED)
	right_leg.set_part(leg_size, Color.INDIAN_RED)


func _get_head_size(spec: Dictionary) -> Vector2:
	var radius := float(spec.get("radius", 0.0)) * DRAW_SCALE
	return Vector2(radius * 2.0, radius * 2.0)


func _get_part_size(spec: Dictionary) -> Vector2:
	return Vector2(
		float(spec.get("width", 0.0)) * DRAW_SCALE,
		float(spec.get("height", 0.0)) * DRAW_SCALE
	)
