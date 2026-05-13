extends Control

const CARD_SIZE := Vector2(116.0, 158.0)
const CARD_OVERLAP_PIXELS := 34.0
const CARD_RAISE_PIXELS := 14.0
const CARD_HOVER_RAISE_PIXELS := 28.0
const CARD_HOVER_SCALE := Vector2(1.08, 1.08)
const CARD_HOVER_SECONDS := 0.12
const BUMP_DAMAGE_MIN := 1
const BUMP_DAMAGE_MAX := 9
const STRONG_BUMP_DAMAGE_MIN := 4
const STRONG_BUMP_DAMAGE_MAX := 9
const STRONG_BUMP_FOCUS_COST := 3
const STRONG_BUMP_VECTOR_LENGTH := 3
const THROW_PROJECTILE_DAMAGE_MIN := 1
const THROW_PROJECTILE_DAMAGE_MAX := 9
const THROW_PROJECTILE_RESOURCE_COST := 0
const CARD_COLORS := [
	Color(0.20, 0.28, 0.34, 1.0),
	Color(0.32, 0.24, 0.30, 1.0),
	Color(0.22, 0.34, 0.26, 1.0),
	Color(0.36, 0.30, 0.20, 1.0),
	Color(0.26, 0.26, 0.38, 1.0),
]

@export var action_queue_path: NodePath
@export var state_store_path: NodePath

@onready var card_stack: Control = $CardStack
@onready var action_queue: Node = get_node_or_null(action_queue_path)
@onready var state_store: Node = get_node_or_null(state_store_path)

var _card_tweens: Dictionary = {}
var _cards: Array[Dictionary] = [
	{
		"title": "Bump",
		"cost": "0",
		"body": "Deal damage",
		"action_factory": "bump",
	},
	{
		"title": "Strong Bump",
		"cost": "3",
		"body": "Heavy hit",
		"action_factory": "strong_bump",
	},
	{
		"title": "Throw",
		"cost": "0",
		"body": "Ranged hit",
		"action_factory": "throw_projectile",
	},
	{
		"title": "Focus",
		"cost": "0",
		"body": "Gain focus",
		"action": {
			"eventName": "perform_cast",
			"payload": {
				"args": {
					"type": "focus",
					"value": 1,
					"source": "hand_gui",
				},
			},
		},
	},
	{
		"title": "Heal",
		"cost": "1",
		"body": "Restore HP",
		"action": {
			"eventName": "perform_cast",
			"payload": {
				"args": {
					"type": "heal",
					"resource": 1,
					"value": 3,
					"source": "hand_gui",
				},
			},
		},
	},
	{
		"title": "Thunder",
		"cost": "1",
		"body": "Hit target",
		"action": {
			"eventName": "perform_cast",
			"payload": {
				"args": {
					"type": "summon_thunder",
					"resource": 3,
					"value": 5,
					"source": "hand_gui",
				},
			},
		},
	},
]


func _ready() -> void:
	randomize()
	resized.connect(_layout_cards)
	_rebuild_cards()


func set_cards(cards: Array[Dictionary]) -> void:
	_cards = cards.duplicate(true)
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child: Node in card_stack.get_children():
		child.queue_free()

	for index in _cards.size():
		var card := _create_card(_cards[index], index)
		card_stack.add_child(card)

	_layout_cards()


func _create_card(card_data: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = index
	card.gui_input.connect(_on_card_gui_input.bind(card_data))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card, index))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card, index))

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLORS[index % CARD_COLORS.size()]
	style.border_color = Color(0.86, 0.88, 0.82, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = str(card_data.get("title", "Card"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var cost := Label.new()
	cost.text = str(card_data.get("cost", "0"))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.add_theme_font_size_override("font_size", 14)
	header.add_child(cost)

	var body := Label.new()
	body.text = str(card_data.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 11)
	content.add_child(body)

	return card


func _on_card_mouse_entered(card: Control, index: int) -> void:
	_tween_card_hover(card, index, true)


func _on_card_mouse_exited(card: Control, index: int) -> void:
	_tween_card_hover(card, index, false)


func _tween_card_hover(card: Control, index: int, is_hovered: bool) -> void:
	if card == null:
		return

	if _card_tweens.has(card):
		var active_tween: Tween = _card_tweens[card]
		if active_tween:
			active_tween.kill()

	var base_position := _get_card_base_position(index, card_stack.get_child_count())
	var centered_index := _get_card_centered_index(index, card_stack.get_child_count())
	var target_position := base_position
	var target_rotation := centered_index * 4.0
	var target_scale := Vector2.ONE
	var target_z_index := index

	if is_hovered:
		target_position.y -= CARD_HOVER_RAISE_PIXELS
		target_rotation = 0.0
		target_scale = CARD_HOVER_SCALE
		target_z_index = 100 + index

	card.pivot_offset = CARD_SIZE / 2.0
	card.z_index = target_z_index
	var tween := create_tween()
	_card_tweens[card] = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_position, CARD_HOVER_SECONDS)
	tween.tween_property(card, "rotation_degrees", target_rotation, CARD_HOVER_SECONDS)
	tween.tween_property(card, "scale", target_scale, CARD_HOVER_SECONDS)
	tween.finished.connect(_on_card_hover_tween_finished.bind(card, tween, target_z_index))


func _on_card_hover_tween_finished(card: Control, tween: Tween, target_z_index: int) -> void:
	if _card_tweens.get(card, null) == tween:
		_card_tweens.erase(card)

	if card != null:
		card.z_index = target_z_index


func _on_card_gui_input(event: InputEvent, card_data: Dictionary) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_enqueue_card_action(card_data)


func _enqueue_card_action(card_data: Dictionary) -> void:
	if action_queue == null:
		push_warning("Cannot enqueue card action without an ActionQueue.")
		return

	var entity_id := _get_first_board_entity_id()
	if entity_id == &"":
		push_warning("Cannot enqueue card action before an entity is on the board.")
		return

	var action := _create_card_action(card_data, entity_id)
	if action.is_empty():
		push_warning("Cannot enqueue card without action data: %s." % card_data)
		return

	action_queue.enQueue([action])


func _create_card_action(card_data: Dictionary, entity_id: StringName) -> Dictionary:
	var action_factory := str(card_data.get("action_factory", ""))
	if action_factory != "":
		return _create_action_from_factory(action_factory, entity_id)

	var action: Dictionary = card_data.get("action", {}).duplicate(true)
	if action.is_empty():
		return {}

	var payload: Dictionary = action.get("payload", {})
	payload["id"] = entity_id
	action["payload"] = payload
	return action


func _create_action_from_factory(action_factory: String, entity_id: StringName) -> Dictionary:
	match action_factory:
		"bump":
			return _create_attack_action(
				entity_id,
				"bump",
				_get_vector_to_target(entity_id, 1),
				randi_range(BUMP_DAMAGE_MIN, BUMP_DAMAGE_MAX)
			)
		"strong_bump":
			return _create_attack_action(
				entity_id,
				"strong_bump",
				_get_vector_to_target(entity_id, STRONG_BUMP_VECTOR_LENGTH),
				randi_range(STRONG_BUMP_DAMAGE_MIN, STRONG_BUMP_DAMAGE_MAX),
				STRONG_BUMP_FOCUS_COST
			)
		"throw_projectile":
			return _create_attack_action(
				entity_id,
				"throw_projectile",
				_get_vector_to_target(entity_id, 1),
				randi_range(THROW_PROJECTILE_DAMAGE_MIN, THROW_PROJECTILE_DAMAGE_MAX),
				THROW_PROJECTILE_RESOURCE_COST
			)
		_:
			push_warning("Unsupported card action factory: %s." % action_factory)
			return {}


func _create_attack_action(entity_id: StringName, attack_type: String, vector: Vector2i, damage: int, resource: Variant = null) -> Dictionary:
	var args := {
		"type": attack_type,
		"damage": damage,
		"source": "hand_gui",
		"vector": vector,
	}
	if resource != null:
		args["resource"] = resource

	return {
		"eventName": "perform_attack",
		"payload": {
			"id": entity_id,
			"args": args,
		},
	}


func _get_vector_to_target(entity_id: StringName, vector_length: int) -> Vector2i:
	var source_cell := _get_entity_board_cell(entity_id)
	var target_cell := _get_first_other_board_cell(entity_id)
	if source_cell == Vector2i(-1, -1) or target_cell == Vector2i(-1, -1):
		return Vector2i.RIGHT * vector_length

	var delta := target_cell - source_cell
	if delta == Vector2i.ZERO:
		return _get_random_horizontal_direction() * vector_length

	var axis_direction := Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		axis_direction.x = signi(delta.x)
	else:
		axis_direction.y = signi(delta.y)

	if axis_direction == Vector2i.ZERO:
		axis_direction = _get_random_horizontal_direction()

	return axis_direction * vector_length


func _get_random_horizontal_direction() -> Vector2i:
	if randi_range(0, 1) == 0:
		return Vector2i.LEFT

	return Vector2i.RIGHT


func _get_first_board_entity_id() -> StringName:
	if state_store == null:
		return &""

	var board: Dictionary = state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for col_cells: Array in cells:
		for cell: Dictionary in col_cells:
			for entity_id: Variant in cell.get(&"entity_ids", []):
				return StringName(str(entity_id))

			var legacy_entity_id := StringName(str(cell.get(&"entity_id", &"")))
			if legacy_entity_id != &"":
				return legacy_entity_id

	return &""


func _get_entity_board_cell(entity_id: StringName) -> Vector2i:
	var board: Dictionary = state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]
		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity(cell, entity_id):
				return Vector2i(int(cell.get(&"i", i)), int(cell.get(&"j", j)))

	return Vector2i(-1, -1)


func _get_first_other_board_cell(entity_id: StringName) -> Vector2i:
	var board: Dictionary = state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]
		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_other_entity(cell, entity_id):
				return Vector2i(int(cell.get(&"i", i)), int(cell.get(&"j", j)))

	return Vector2i(-1, -1)


func _cell_has_entity(cell: Dictionary, entity_id: StringName) -> bool:
	for cell_entity_id: Variant in cell.get(&"entity_ids", []):
		if StringName(str(cell_entity_id)) == entity_id:
			return true

	return StringName(str(cell.get(&"entity_id", &""))) == entity_id


func _cell_has_other_entity(cell: Dictionary, entity_id: StringName) -> bool:
	for cell_entity_id: Variant in cell.get(&"entity_ids", []):
		var cell_entity_string_name := StringName(str(cell_entity_id))
		if cell_entity_string_name != &"" and cell_entity_string_name != entity_id:
			return true

	var legacy_entity_id := StringName(str(cell.get(&"entity_id", &"")))
	return legacy_entity_id != &"" and legacy_entity_id != entity_id


func signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0


func _layout_cards() -> void:
	if card_stack == null:
		return

	var card_count := card_stack.get_child_count()
	if card_count == 0:
		return

	var step := CARD_SIZE.x - CARD_OVERLAP_PIXELS
	var stack_width := CARD_SIZE.x + step * float(card_count - 1)
	var stack_height := CARD_SIZE.y + CARD_RAISE_PIXELS
	card_stack.size = Vector2.ZERO

	for index in card_count:
		var card := card_stack.get_child(index) as Control
		var centered_index := _get_card_centered_index(index, card_count)
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE / 2.0
		card.position = _get_card_base_position(index, card_count)
		card.rotation_degrees = centered_index * 4.0


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
