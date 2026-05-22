extends Node2D

var _board: Dictionary = {}
var _cell_nodes: Array[Node] = []

@onready var state_store: Node = $"../../BattleStateStore"
@onready var cell_anchor: Node2D = $CellAnchor
@onready var cell_template: Control = $CellAnchor/CellTemplate


func _ready() -> void:
	cell_template.visible = false
	state_store.board_init.connect(_on_board_init)


func _on_board_init(board: Dictionary, _previous_board: Variant) -> void:
	_board = _with_template_cell_size(board)
	state_store.set_value(&"board", _board)
	_rebuild_cells()


func index_to_position(i: int, j: int) -> Vector2:
	var cell_size := _get_cell_size()

	return cell_anchor.position + Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 0.5) * cell_size.y
	)


func index_to_bottom_position(i: int, j: int) -> Vector2:
	var cell_size := _get_cell_size()

	return cell_anchor.position + Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 1.0) * cell_size.y
	)


func _rebuild_cells() -> void:
	for cell_node: Node in _cell_nodes:
		cell_node.queue_free()
	_cell_nodes.clear()

	var cols := int(_board.get(&"cols", 0))
	var rows := int(_board.get(&"rows", 0))
	if cols <= 0 or rows <= 0:
		return

	var cell_size := _get_cell_size()
	if cell_size == Vector2.ZERO:
		return

	for i in cols:
		for j in rows:
			var cell := cell_template.duplicate() as Control
			cell.name = "Cell_%d_%d" % [i, j]
			cell.visible = true
			cell.position = Vector2(i * cell_size.x, j * cell_size.y)
			cell.custom_minimum_size = cell_size
			cell.size = cell_size
			cell_anchor.add_child(cell)
			_cell_nodes.append(cell)


func _get_cell_size() -> Vector2:
	return _get_template_cell_size()


func _get_template_cell_size() -> Vector2:
	if cell_template.size != Vector2.ZERO:
		return cell_template.size

	return cell_template.custom_minimum_size


func _with_template_cell_size(board: Dictionary) -> Dictionary:
	var next_board := board.duplicate(true)
	next_board[&"cell_size"] = _get_template_cell_size()
	return next_board
