extends Node2D

var _character_size := Vector2.ZERO

@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	state_store.character_initialized.connect(_on_character_initialized)


func _on_character_initialized(character: Dictionary, _previous_character: Variant) -> void:
	_character_size = Vector2(
		float(character.get("width", 0.0)),
		float(character.get("height", 0.0))
	)
	queue_redraw()


func _draw() -> void:
	if _character_size == Vector2.ZERO:
		return

	draw_rect(Rect2(Vector2.ZERO, _character_size), Color.CORNFLOWER_BLUE)
