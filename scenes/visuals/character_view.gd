extends Node2D

const DRAW_SCALE := 5.0

var _character_size := Vector2.ZERO

@onready var state_store: Node = $"../../StateStore"
@onready var head: Node2D = $Head
@onready var neck: Node2D = $Neck
@onready var body: Node2D = $Body
@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm
@onready var left_leg: Node2D = $LeftLeg
@onready var right_leg: Node2D = $RightLeg


func _ready() -> void:
	state_store.character_initialized.connect(_on_character_initialized)


func _on_character_initialized(character: Dictionary, _previous_character: Variant) -> void:
	_character_size = Vector2(
		float(character.get("width", 0.0)),
		float(character.get("height", 0.0))
	)
	_update_parts()


func _update_parts() -> void:
	if _character_size == Vector2.ZERO:
		return

	var width = _character_size.x * DRAW_SCALE
	var height = _character_size.y * DRAW_SCALE

	var head_size := Vector2(width * 0.45, height * 0.25)
	var neck_size := Vector2(width * 0.2, height * 0.08)
	var body_size := Vector2(width * 0.5, height * 0.4)
	var arm_size := Vector2(width * 0.2, height * 0.35)
	var leg_size := Vector2(width * 0.22, height * 0.35)

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
