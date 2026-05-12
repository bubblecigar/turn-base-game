extends Node2D

const GRID_COLOR := Color(0.2, 0.2, 0.2)
const FILL_COLOR := Color(0.92, 0.94, 0.96)
const LINE_WIDTH := 2.0

var _board: Dictionary = {}

@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	state_store.board_init.connect(_on_board_init)


func _on_board_init(board: Dictionary, _previous_board: Variant) -> void:
	_board = board
	_center_on_viewport()
	queue_redraw()


func _center_on_viewport() -> void:
	var cols := int(_board.get(&"cols", 0))
	var rows := int(_board.get(&"rows", 0))
	var cell_size: Vector2 = _board.get(&"cell_size", Vector2.ZERO)
	if cols <= 0 or rows <= 0 or cell_size == Vector2.ZERO:
		return

	var board_size := Vector2(cols * cell_size.x, rows * cell_size.y)
	var viewport_size := get_viewport_rect().size
	position = ((viewport_size - board_size) / 2.0).floor()


func index_to_position(i: int, j: int) -> Vector2:
	var cell_size := _get_cell_size()

	return Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 0.5) * cell_size.y
	)


func index_to_bottom_position(i: int, j: int) -> Vector2:
	var cell_size := _get_cell_size()

	return Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 1.0) * cell_size.y
	)


func _draw() -> void:
	if _board.is_empty():
		return

	var cols := int(_board.get(&"cols", 0))
	var rows := int(_board.get(&"rows", 0))

	if cols <= 0 or rows <= 0:
		return

	var cell_size := _get_cell_size()
	var board_size := Vector2(cols * cell_size.x, rows * cell_size.y)
	draw_rect(Rect2(Vector2.ZERO, board_size), FILL_COLOR, true)

	for i in cols + 1:
		var x := i * cell_size.x
		draw_line(Vector2(x, 0.0), Vector2(x, board_size.y), GRID_COLOR, LINE_WIDTH)

	for j in rows + 1:
		var y := j * cell_size.y
		draw_line(Vector2(0.0, y), Vector2(board_size.x, y), GRID_COLOR, LINE_WIDTH)


func _get_cell_size() -> Vector2:
	return _board.get(&"cell_size", Vector2.ZERO)
