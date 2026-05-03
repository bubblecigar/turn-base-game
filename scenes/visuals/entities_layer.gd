extends Node2D

const CHARACTER_SCENE := preload("res://scenes/visuals/CharacterScene.tscn")
const FALLBACK_ENTITY_SPACING := Vector2(96.0, 0.0)

@onready var state_store: Node = $"../../StateStore"
@onready var board_view: Node = $"../BoardView"


func _ready() -> void:
	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	draw_entities(state_store.get_value(&"entities", {}))


func _on_entities_updated(entities: Dictionary, _previous_entities: Variant) -> void:
	draw_entities(entities)


func _on_board_init(_board: Dictionary, _previous_board: Variant) -> void:
	draw_entities(state_store.get_value(&"entities", {}))


func draw_entities(entities: Dictionary) -> void:
	_clear_entities()

	var index := 0
	for entity_id: Variant in entities:
		var entity: Variant = entities[entity_id]
		if not entity is Dictionary:
			continue

		var character_view: Node2D = CHARACTER_SCENE.instantiate()
		add_child(character_view)
		character_view.set_character_spec(entity)
		character_view.position = _get_entity_position(entity, index, character_view.get_character_size())
		index += 1


func _clear_entities() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _get_entity_position(entity: Dictionary, fallback_index: int, character_size: Vector2) -> Vector2:
	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_entity_board_index(board, entity)
	if board_index == Vector2i(-1, -1):
		return FALLBACK_ENTITY_SPACING * fallback_index

	return (
		board_view.position
		+ board_view.index_to_bottom_position(board_index.x, board_index.y)
		- Vector2(character_size.x / 2.0, character_size.y)
	)


func _get_entity_board_index(board: Dictionary, entity: Dictionary) -> Vector2i:
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _is_same_entity(cell.get(&"entity"), entity):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _is_same_entity(cell_entity: Variant, entity: Dictionary) -> bool:
	return (
		cell_entity is Dictionary
		and cell_entity.get(&"id", &"") == entity.get(&"id", &"")
	)
