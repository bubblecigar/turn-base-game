extends RefCounted

var _card_hand_view: Control
var _dragging_card_index := -1
var _dragging_card: Control
var _dragging_card_data: Dictionary = {}
var _drag_offset := Vector2.ZERO


func _init(card_hand_view: Control) -> void:
	_card_hand_view = card_hand_view


func is_dragging() -> bool:
	return _dragging_card != null


func get_dragging_card_index() -> int:
	return _dragging_card_index


func start_drag(card_data: Dictionary, index: int, card: Control) -> void:
	if card == null:
		return

	_dragging_card_index = index
	_dragging_card = card
	_dragging_card_data = card_data
	_drag_offset = _get_card_hand_mouse_position() - card.position
	if _card_hand_view != null:
		_card_hand_view.prepare_card_for_drag(card, index)
	update_dragged_card_position()


func update_dragged_card_position() -> void:
	if _dragging_card == null:
		return

	_dragging_card.position = _get_card_hand_mouse_position() - _drag_offset


func get_drag_snapshot() -> Dictionary:
	return {
		"card": _dragging_card,
		"index": _dragging_card_index,
		"data": _dragging_card_data.duplicate(true),
	}


func clear_drag() -> void:
	_dragging_card_index = -1
	_dragging_card = null
	_dragging_card_data = {}
	_drag_offset = Vector2.ZERO
	if _card_hand_view != null:
		_card_hand_view.set_dragging_card_index(-1)


func _get_card_hand_mouse_position() -> Vector2:
	if _card_hand_view == null:
		return Vector2.ZERO

	return _card_hand_view.get_mouse_position_in_hand()
