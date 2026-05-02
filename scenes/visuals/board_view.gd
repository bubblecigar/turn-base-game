extends Node2D

const CELL_SIZE := Vector2(72.0, 72.0)
const GRID_COLOR := Color(0.2, 0.2, 0.2)
const FILL_COLOR := Color(0.92, 0.94, 0.96)
const LINE_WIDTH := 2.0

var _board: Dictionary = {}

@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	state_store.board_init.connect(_on_board_init)


func _on_board_init(board: Dictionary, _previous_board: Variant) -> void:
	_board = board
	queue_redraw()


func _draw() -> void:
	if _board.is_empty():
		return

	var cols := int(_board.get(&"cols", 0))
	var rows := int(_board.get(&"rows", 0))

	if cols <= 0 or rows <= 0:
		return

	var board_size := Vector2(cols * CELL_SIZE.x, rows * CELL_SIZE.y)
	draw_rect(Rect2(Vector2.ZERO, board_size), FILL_COLOR, true)

	for i in cols + 1:
		var x := i * CELL_SIZE.x
		draw_line(Vector2(x, 0.0), Vector2(x, board_size.y), GRID_COLOR, LINE_WIDTH)

	for j in rows + 1:
		var y := j * CELL_SIZE.y
		draw_line(Vector2(0.0, y), Vector2(board_size.x, y), GRID_COLOR, LINE_WIDTH)
