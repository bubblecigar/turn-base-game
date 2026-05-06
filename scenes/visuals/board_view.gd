extends Node2D

const GRID_COLOR := Color(0.2, 0.2, 0.2)
const FILL_COLOR := Color(0.92, 0.94, 0.96)
const LINE_WIDTH := 2.0
const WALL_THICKNESS := LINE_WIDTH

var _board: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []

@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	state_store.board_init.connect(_on_board_init)


func _on_board_init(board: Dictionary, _previous_board: Variant) -> void:
	_board = board
	_rebuild_grid_walls()
	queue_redraw()


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


func _rebuild_grid_walls() -> void:
	_clear_grid_walls()

	if _board.is_empty():
		return

	var cols := int(_board.get(&"cols", 0))
	var rows := int(_board.get(&"rows", 0))
	if cols <= 0 or rows <= 0:
		return

	var cell_size := _get_cell_size()
	if cell_size == Vector2.ZERO:
		return

	var board_size := Vector2(cols * cell_size.x, rows * cell_size.y)

	_add_grid_wall(
		"TableWallLeft",
		Vector2(0.0, board_size.y / 2.0),
		Vector2(WALL_THICKNESS, board_size.y + WALL_THICKNESS)
	)
	_add_grid_wall(
		"TableWallRight",
		Vector2(board_size.x, board_size.y / 2.0),
		Vector2(WALL_THICKNESS, board_size.y + WALL_THICKNESS)
	)
	_add_grid_wall(
		"TableWallTop",
		Vector2(board_size.x / 2.0, 0.0),
		Vector2(board_size.x + WALL_THICKNESS, WALL_THICKNESS)
	)
	_add_grid_wall(
		"TableWallBottom",
		Vector2(board_size.x / 2.0, board_size.y),
		Vector2(board_size.x + WALL_THICKNESS, WALL_THICKNESS)
	)


func _add_grid_wall(wall_name: String, wall_position: Vector2, wall_size: Vector2) -> void:
	var wall_body := StaticBody2D.new()
	wall_body.name = wall_name
	wall_body.position = wall_position

	var collision_shape := CollisionShape2D.new()
	var rectangle_shape := RectangleShape2D.new()
	rectangle_shape.size = wall_size
	collision_shape.shape = rectangle_shape
	wall_body.add_child(collision_shape)

	add_child(wall_body)
	_wall_bodies.append(wall_body)


func _clear_grid_walls() -> void:
	for wall_body: StaticBody2D in _wall_bodies:
		if is_instance_valid(wall_body):
			wall_body.queue_free()

	_wall_bodies.clear()
