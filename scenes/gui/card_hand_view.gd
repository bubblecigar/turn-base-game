extends Control

signal card_gui_input(event: InputEvent, card_data: Dictionary, index: int, card: Control)

const CARD_SIZE := Vector2(116.0, 158.0)
const CARD_OVERLAP_PIXELS := 34.0
const CARD_RAISE_PIXELS := 14.0
const CARD_HOVER_RAISE_PIXELS := 28.0
const CARD_ANIMATION_SECONDS := 0.12
const CARD_TITLE_LABEL_NAME := "TitleLabel"
const CARD_COST_LABEL_NAME := "CostLabel"
const CARD_BODY_LABEL_NAME := "BodyLabel"
const CARD_COLORS := [
	Color(0.20, 0.28, 0.34, 1.0),
	Color(0.32, 0.24, 0.30, 1.0),
	Color(0.22, 0.34, 0.26, 1.0),
	Color(0.36, 0.30, 0.20, 1.0),
	Color(0.26, 0.26, 0.38, 1.0),
]

var _card_face_template: Panel
var _selection_slot_position_provider: Callable
var _player_entity_id_provider: Callable
var _card_tweens: Dictionary = {}
var _next_card_tween_id := 0
var _card_nodes: Array[Control] = []
var _active_cards: Array[Dictionary] = []
var _selected_card_index := -1
var _dragging_card_index := -1


func setup(card_face_template: Panel, selection_slot_position_provider: Callable, player_entity_id_provider: Callable) -> void:
	_card_face_template = card_face_template
	_selection_slot_position_provider = selection_slot_position_provider
	_player_entity_id_provider = player_entity_id_provider


func get_card_count() -> int:
	return _card_nodes.size()


func get_card(index: int) -> Control:
	if index < 0 or index >= _card_nodes.size():
		return null

	return _card_nodes[index]


func get_mouse_position_in_hand() -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * get_global_mouse_position()


func set_dragging_card_index(index: int) -> void:
	_dragging_card_index = index


func prepare_card_for_drag(card: Control, index: int) -> void:
	if card == null:
		return

	_stop_card_animation(card)
	_dragging_card_index = index
	_apply_fixed_card_size(card)
	card.rotation_degrees = 0.0
	card.scale = Vector2.ONE
	card.z_index = 300 + index


func update_card_enabled_states(focus: int, pending_entity_ids: Dictionary, player_entity_id: StringName) -> void:
	for i in _card_nodes.size():
		var card := _card_nodes[i]
		if card == null:
			continue
		var args: Dictionary = _active_cards[i].get("args", {})
		var cost := int(args.get("resource", 0))
		var is_selected := i == _selected_card_index
		var is_affordable := focus >= cost
		var is_pending := pending_entity_ids.has(player_entity_id) and is_selected
		if is_pending:
			card.modulate = Color(0.70, 0.70, 0.70, 0.85)
		elif is_selected:
			card.modulate = Color(1.0, 0.95, 0.55, 1.0)
		elif is_affordable:
			card.modulate = Color.WHITE
		else:
			card.modulate = Color(0.45, 0.45, 0.45, 0.65)


func rebuild_cards(active_cards: Array[Dictionary], selected_card_index: int, dragging_card_index: int) -> void:
	_card_nodes.clear()
	_active_cards = active_cards.duplicate(true)
	_selected_card_index = selected_card_index
	_dragging_card_index = dragging_card_index
	_stop_all_card_animations()

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	for index in _active_cards.size():
		var card := _create_card(_active_cards[index], index)
		add_child(card)
		_card_nodes.append(card)

	layout_cards()


func _create_card(card_data: Dictionary, index: int) -> Panel:
	var card := _card_face_template.duplicate() as Panel if _card_face_template != null else Panel.new()
	card.name = "Card_%d" % index
	_apply_fixed_card_size(card)
	card.visible = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = index
	card.gui_input.connect(_on_card_gui_input.bind(card_data, index, card))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card, index))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card, index))

	var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.bg_color = CARD_COLORS[index % CARD_COLORS.size()]
		card.add_theme_stylebox_override("panel", style)

	_set_label_text(card, CARD_TITLE_LABEL_NAME, str(card_data.get("title", "Card")))
	_set_label_text(card, CARD_COST_LABEL_NAME, _get_card_cost_text(card_data))
	_set_label_text(card, CARD_BODY_LABEL_NAME, str(card_data.get("body", "")))

	return card


func layout_cards(animate_selected: bool = false, selected_card_index: int = -9999, dragging_card_index: int = -9999) -> void:
	if selected_card_index != -9999:
		_selected_card_index = selected_card_index
	if dragging_card_index != -9999:
		_dragging_card_index = dragging_card_index

	var card_count := get_child_count()
	if card_count == 0:
		return

	size = Vector2.ZERO

	for index in card_count:
		var card := get_child(index) as Control
		if index == _dragging_card_index:
			continue
		if index == _selected_card_index:
			move_card_to_selection_slot(card, index, _get_player_entity_id(), animate_selected)
			continue

		move_card_to_layout_position(card, index, false)


func move_card_to_layout_position(card: Control, index: int, animated: bool) -> void:
	if card == null:
		return

	var card_count := _card_nodes.size()
	var centered_index := _get_card_centered_index(index, card_count)
	var target_position := _get_card_base_position(index, card_count)
	var target_rotation := centered_index * 4.0
	var target_z_index := index

	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	_apply_card_pose(card, target_position, target_rotation, Vector2.ONE, target_z_index, animated)


func move_card_to_selection_slot(card: Control, index: int, entity_id: StringName, animated: bool) -> void:
	if card == null:
		return

	var target_position := _get_selection_slot_card_position(entity_id)
	var target_z_index := 150 + index
	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	_apply_card_pose(card, target_position, 0.0, Vector2.ONE, target_z_index, animated)


func _set_card_hover_state(card: Control, index: int, is_hovered: bool) -> void:
	if card == null:
		return
	if index == _dragging_card_index or index == _selected_card_index:
		return

	var base_position := _get_card_base_position(index, get_child_count())
	var centered_index := _get_card_centered_index(index, get_child_count())
	var target_position := base_position
	var target_rotation := centered_index * 4.0
	var target_scale := Vector2.ONE
	var target_z_index := index

	if is_hovered:
		target_position.y -= CARD_HOVER_RAISE_PIXELS
		target_rotation = 0.0
		target_z_index = 100 + index

	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	_apply_card_pose(card, target_position, target_rotation, target_scale, target_z_index, true)


func _get_card_base_position(index: int, card_count: int) -> Vector2:
	var step := CARD_SIZE.x - CARD_OVERLAP_PIXELS
	var stack_width := CARD_SIZE.x + step * float(card_count - 1)
	var centered_index := _get_card_centered_index(index, card_count)
	return Vector2(
		-stack_width / 2.0 + step * index,
		-CARD_SIZE.y / 2.0 + absf(centered_index) * CARD_RAISE_PIXELS * 0.35
	)


func _get_card_centered_index(index: int, card_count: int) -> float:
	return float(index) - float(card_count - 1) / 2.0


func _apply_fixed_card_size(card: Control) -> void:
	if card == null:
		return

	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.scale = Vector2.ONE


func _set_label_text(root: Node, label_name: String, text: String) -> void:
	var label := root.find_child(label_name, true, false) as Label
	if label == null:
		return

	label.text = text


func float_card_back_to_hand(card: Control, index: int, finished_callback: Callable) -> void:
	if card == null:
		return

	var card_count := _card_nodes.size()
	var centered_index := _get_card_centered_index(index, card_count)
	var target_position := _get_card_base_position(index, card_count)
	var target_rotation := centered_index * 4.0
	var target_z_index := index

	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	_apply_card_pose(card, target_position, target_rotation, Vector2.ONE, target_z_index, true, finished_callback)


func _on_card_gui_input(event: InputEvent, card_data: Dictionary, index: int, card: Control) -> void:
	card_gui_input.emit(event, card_data, index, card)


func _on_card_mouse_entered(card: Control, index: int) -> void:
	_set_card_hover_state(card, index, true)


func _on_card_mouse_exited(card: Control, index: int) -> void:
	_set_card_hover_state(card, index, false)


func _get_card_cost_text(card_data: Dictionary) -> String:
	var args: Dictionary = card_data.get("args", card_data.get("action", {}).get("payload", {}).get("args", {}))
	var resource := int(args.get("resource", 0))
	return str(resource) if resource > 0 else ""


func _get_selection_slot_card_position(entity_id: StringName) -> Vector2:
	if not _selection_slot_position_provider.is_valid():
		return Vector2.ZERO

	return _selection_slot_position_provider.call(entity_id)


func _get_player_entity_id() -> StringName:
	if not _player_entity_id_provider.is_valid():
		return &""

	return _player_entity_id_provider.call()


func _apply_card_pose(
	card: Control,
	target_position: Vector2,
	target_rotation: float,
	target_scale: Vector2,
	target_z_index: int,
	animated: bool,
	finished_callback: Callable = Callable()
) -> void:
	if card == null:
		return

	_stop_card_animation(card)
	card.z_index = target_z_index
	if not animated:
		card.position = target_position
		card.rotation_degrees = target_rotation
		card.scale = target_scale
		if finished_callback.is_valid():
			finished_callback.call(card, target_z_index)
		return

	_next_card_tween_id += 1
	var tween_id := _next_card_tween_id
	var tween := create_tween()
	_card_tweens[card] = {
		"tween": tween,
		"id": tween_id,
	}
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_position, CARD_ANIMATION_SECONDS)
	tween.tween_property(card, "rotation_degrees", target_rotation, CARD_ANIMATION_SECONDS)
	tween.tween_property(card, "scale", target_scale, CARD_ANIMATION_SECONDS)
	tween.finished.connect(_on_card_animation_finished.bind(card, tween, tween_id, target_z_index, finished_callback))


func _on_card_animation_finished(card: Control, tween: Tween, tween_id: int, target_z_index: int, finished_callback: Callable) -> void:
	var current: Dictionary = _card_tweens.get(card, {})
	if current.get("tween", null) != tween or int(current.get("id", -1)) != tween_id:
		return

	_card_tweens.erase(card)
	if card != null:
		card.z_index = target_z_index
	if finished_callback.is_valid():
		finished_callback.call(card, target_z_index)


func _stop_all_card_animations() -> void:
	for raw_state: Variant in _card_tweens.values():
		var state: Dictionary = raw_state
		var tween := state.get("tween", null) as Tween
		if tween != null:
			tween.kill()
	_card_tweens.clear()


func _stop_card_animation(card: Control) -> void:
	var state: Dictionary = _card_tweens.get(card, {})
	var tween := state.get("tween", null) as Tween
	if tween != null:
		tween.kill()
	_card_tweens.erase(card)
