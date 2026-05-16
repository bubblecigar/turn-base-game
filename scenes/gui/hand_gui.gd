extends Control

const CardActionFactory := preload("res://scenes/gui/CardActionFactory.gd")
const SelectionSlotsView := preload("res://scenes/gui/SelectionSlotsView.gd")
const CardHandView := preload("res://scenes/gui/card_hand_view.gd")
const CARD_SIZE := Vector2(116.0, 158.0)
const ENTITY_CARD_POOL_SIZE := 5

@export var action_queue_path: NodePath
@export var action_handler_path: NodePath
@export var state_store_path: NodePath
@export var game_loop_path: NodePath

@onready var card_stack: CardHandView = $CardStackAnchor/CardStack
@onready var confirm_button: Button = $ConfirmButton
@onready var selection_slots_view: SelectionSlotsView = $SelectionSlots
@onready var card_templates_root: Control = $CardTemplates
@onready var card_face_template: Panel = $CardTemplates/CardFaceTemplate
@onready var card_back_template: Panel = $CardTemplates/CardBackTemplate
@onready var action_queue: Node = get_node_or_null(action_queue_path)
@onready var action_handler: Node = get_node_or_null(action_handler_path)
@onready var state_store: Node = get_node_or_null(state_store_path)
@onready var game_loop: Node = get_node_or_null(game_loop_path)

var _selected_card_index: int = -1
var _dragging_card_index: int = -1
var _dragging_card: Control
var _dragging_card_data: Dictionary = {}
var _drag_offset := Vector2.ZERO
var _active_cards: Array[Dictionary] = []
var _pending_confirmed_card_actions: Dictionary = {}
var _pending_card_return_count := 0
var _cards: Array[Dictionary] = _load_card_templates()
var _card_action_factory: RefCounted


static func _load_card_templates() -> Array[Dictionary]:
	var file := FileAccess.open("res://scenes/gui/card_templates.json", FileAccess.READ)
	if file == null:
		push_error("Failed to open card_templates.json")
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("card_templates.json must be a JSON object")
		return []
	var result: Array[Dictionary] = []
	for id: String in (parsed as Dictionary):
		var item: Variant = (parsed as Dictionary)[id]
		if item is Dictionary:
			var entry := (item as Dictionary).duplicate()
			entry["id"] = id
			result.append(entry)
	return result


func _ready() -> void:
	randomize()
	_card_action_factory = CardActionFactory.new(state_store)
	if card_stack != null:
		card_stack.setup(card_face_template, Callable(self, "_get_selection_slot_card_position"), Callable(self, "_get_player_entity_id"))
		card_stack.card_gui_input.connect(_on_card_gui_input)
	if selection_slots_view != null:
		selection_slots_view.setup(state_store, card_back_template, self, CARD_SIZE)
	if card_templates_root != null:
		card_templates_root.visible = false
	_sync_selection_slots()
	resized.connect(_update_slot_card_preview_positions)
	resized.connect(_layout_card_hand)
	if state_store != null:
		state_store.entities_updated.connect(_on_entities_updated)
		state_store.entity_selection_changed.connect(_on_entity_selection_changed)
		state_store.selected_card_changed.connect(_on_selected_card_changed)
		state_store.entity_card_pools_changed.connect(_on_entity_card_pools_changed)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)

	if action_handler != null:
		action_handler.turn_end.connect(_on_action_handler_turn_end)
	_ensure_card_pools_for_entities(state_store.get_value(&"entities", {}) if state_store != null else {}, {})
	_refresh_cards_for_current_entity()


func set_cards(cards: Array[Dictionary]) -> void:
	_cards = cards.duplicate(true)
	_ensure_card_pools_for_entities(state_store.get_value(&"entities", {}) if state_store != null else {}, {})
	_refresh_cards_for_current_entity()


func _rebuild_card_hand() -> void:
	_clear_card_drag()
	if card_stack != null:
		card_stack._rebuild_cards(_active_cards, _selected_card_index, _dragging_card_index)
	_update_card_enabled_states()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _on_entities_updated(_entities: Dictionary, _previous: Variant) -> void:
	_ensure_card_pools_for_entities(_entities, _previous)
	_sync_selection_slots()
	_refresh_cards_for_current_entity()
	_update_card_enabled_states()


func _on_entity_selection_changed(_entity_id: StringName, _previous: StringName) -> void:
	_refresh_cards_for_current_entity()
	_update_card_enabled_states()


func _on_selected_card_changed(entity_id: StringName, _card_data: Dictionary) -> void:
	if entity_id == _get_player_entity_id():
		_update_selected_card_index()
		_layout_card_hand(true)
		_update_selection_slot_state()
		_update_slot_card_previews()
	_update_card_enabled_states()


func _on_entity_card_pools_changed(_entity_card_pools: Dictionary, _previous: Variant) -> void:
	_refresh_cards_for_current_entity()


func _get_player_focus() -> int:
	var entity_id := _get_player_entity_id()
	if entity_id == &"" or state_store == null:
		return 0
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var entity: Dictionary = entities.get(entity_id, {})
	return int(entity.get(&"focus", 0))


func _get_player_entity_id() -> StringName:
	if state_store == null:
		return &""
	var selected: StringName = state_store.get_selected_entity_id()
	if selected != &"":
		return selected
	return _get_first_board_entity_id()


func _update_card_enabled_states() -> void:
	if confirm_button != null:
		var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {}) if state_store != null else {}
		confirm_button.disabled = not _has_unconfirmed_selected_card(selected_cards)
	if card_stack != null:
		card_stack.update_card_enabled_states(_get_player_focus(), _pending_confirmed_card_actions, _get_player_entity_id())


func _on_card_gui_input(event: InputEvent, card_data: Dictionary, index: int, card: Control) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var args: Dictionary = card_data.get("args", {})
	if _get_player_focus() < int(args.get("resource", 0)):
		return
	if _pending_confirmed_card_actions.has(_get_player_entity_id()):
		return

	if mouse_event.double_click:
		_select_card(card_data)
		accept_event()
		return

	_start_card_drag(card_data, index, card)


func _select_card(card_data: Dictionary) -> void:
	var entity_id := _get_player_entity_id()
	if entity_id == &"":
		return

	_select_card_for_entity(entity_id, card_data)


func _select_card_for_entity(entity_id: StringName, card_data: Dictionary) -> void:
	if entity_id == &"":
		return
	if _pending_confirmed_card_actions.has(entity_id):
		return

	var index := _active_cards.find(card_data)
	if entity_id == _get_player_entity_id():
		_selected_card_index = index

	if state_store != null:
		state_store.select_card(entity_id, card_data)

	_layout_card_hand(true)
	_update_card_enabled_states()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _on_confirm_pressed() -> void:
	if state_store == null:
		return

	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {})
	if selected_cards.is_empty():
		return

	var action_stack: Array[Dictionary] = []
	var confirmed_actions: Dictionary = {}
	for raw_id: Variant in selected_cards:
		var entity_id := StringName(str(raw_id))
		if _pending_confirmed_card_actions.has(entity_id):
			continue
		var card_data: Dictionary = selected_cards[raw_id]
		if card_data.is_empty():
			continue
		var action := _create_card_action(card_data, entity_id)
		if action.is_empty():
			push_warning("Cannot enqueue card without action data: %s." % card_data)
			continue
		action_stack.append(action)
		confirmed_actions[entity_id] = action.duplicate(true)

	if not action_stack.is_empty():
		if action_queue == null:
			push_warning("Cannot enqueue card action without an ActionQueue.")
		else:
			for entity_id: Variant in confirmed_actions:
				_pending_confirmed_card_actions[entity_id] = confirmed_actions[entity_id]
			var batches := _create_ordered_action_batches_from_stack(action_stack)
			for batch: Array in batches:
				action_queue.enQueue(batch)

	_layout_card_hand()
	_update_card_enabled_states()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _has_unconfirmed_selected_card(selected_cards: Dictionary) -> bool:
	for raw_id: Variant in selected_cards:
		var entity_id := StringName(str(raw_id))
		if not _pending_confirmed_card_actions.has(entity_id):
			return true

	return false


func _on_action_handler_turn_end(_event: Dictionary) -> void:
	if _pending_confirmed_card_actions.is_empty():
		return

	_float_pending_cards_back_to_hand()


func _float_pending_cards_back_to_hand() -> void:
	var pending_entity_ids: Array[StringName] = []
	for raw_entity_id: Variant in _pending_confirmed_card_actions.keys():
		pending_entity_ids.append(StringName(str(raw_entity_id)))

	var animated_count := 0
	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {}) if state_store != null else {}
	_pending_card_return_count = 0
	for entity_id: StringName in pending_entity_ids:
		var card_data: Dictionary = selected_cards.get(entity_id, {})
		var card_index := _active_cards.find(card_data)
		if card_stack == null or card_index < 0 or card_index >= card_stack.get_card_count():
			continue

		var card := card_stack.get_card(card_index)
		if card == null:
			continue

		animated_count += 1
		_pending_card_return_count += 1
		card_stack._float_card_back_to_hand(card, card_index, _on_pending_card_return_tween_finished.bind(pending_entity_ids))

	if animated_count == 0:
		_clear_pending_cards_after_return(pending_entity_ids)


func _on_pending_card_return_tween_finished(card: Control, target_z_index: int, pending_entity_ids: Array[StringName]) -> void:
	if card != null:
		card.z_index = target_z_index

	_pending_card_return_count = maxi(_pending_card_return_count - 1, 0)
	if _pending_card_return_count == 0:
		_clear_pending_cards_after_return(pending_entity_ids)


func _clear_pending_cards_after_return(pending_entity_ids: Array[StringName]) -> void:
	for entity_id: StringName in pending_entity_ids:
		_clear_selected_card_for_entity(entity_id)
		_pending_confirmed_card_actions.erase(entity_id)

	_update_selected_card_index()
	_layout_card_hand()
	_update_card_enabled_states()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _clear_selected_card_for_entity(entity_id: StringName) -> void:
	if state_store == null:
		return

	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {})
	if not selected_cards.has(entity_id):
		return

	var next_selected_cards := selected_cards.duplicate(true)
	next_selected_cards.erase(entity_id)
	state_store.set_value(&"selected_cards", next_selected_cards)


func _ensure_card_pools_for_entities(entities: Dictionary, _previous_entities: Variant) -> void:
	if state_store == null:
		return

	for raw_entity_id: Variant in entities:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id == &"" or state_store.has_entity_card_pool(entity_id):
			continue

		state_store.set_entity_card_pool(entity_id, _create_random_card_pool())


func _create_random_card_pool() -> Array[Dictionary]:
	var card_pool: Array[Dictionary] = []
	var available_cards := _cards.duplicate(true)
	available_cards.shuffle()

	var count := mini(ENTITY_CARD_POOL_SIZE, available_cards.size())
	for index in count:
		var card: Dictionary = available_cards[index]
		card_pool.append(card.duplicate(true))

	return card_pool


func _refresh_cards_for_current_entity() -> void:
	_clear_card_drag()
	_active_cards = _get_current_entity_cards()
	_update_selected_card_index()
	_rebuild_card_hand()


func _get_current_entity_cards() -> Array[Dictionary]:
	if state_store == null:
		return _cards.duplicate(true)

	var entity_id := _get_player_entity_id()
	if entity_id == &"":
		return []

	return state_store.get_entity_card_pool(entity_id)


func _update_selected_card_index() -> void:
	_selected_card_index = -1
	if state_store == null:
		return

	var entity_id := _get_player_entity_id()
	if entity_id == &"":
		return

	var selected_card: Dictionary = state_store.get_selected_card(entity_id)
	if selected_card.is_empty():
		return

	for index in _active_cards.size():
		if _active_cards[index] == selected_card:
			_selected_card_index = index
			return


func _input(event: InputEvent) -> void:
	if _dragging_card == null:
		return

	if event is InputEventMouseMotion:
		_update_dragged_card_position()
		_update_selection_slot_state()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_card_drag(_get_hovered_selection_slot_entity_id())


func _sync_selection_slots() -> void:
	if selection_slots_view == null:
		return

	selection_slots_view.sync_slots()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _layout_selection_slots() -> void:
	_update_slot_card_preview_positions()


func _start_card_drag(card_data: Dictionary, index: int, card: Control) -> void:
	if card == null:
		return

	_dragging_card_index = index
	_dragging_card = card
	_dragging_card_data = card_data
	_drag_offset = _get_card_stack_mouse_position() - card.position
	if card_stack != null:
		card_stack.prepare_card_for_drag(card, index)
	_update_dragged_card_position()
	_update_selection_slot_state()


func _update_dragged_card_position() -> void:
	if _dragging_card == null:
		return

	_dragging_card.position = _get_card_stack_mouse_position() - _drag_offset


func _finish_card_drag(target_entity_id: StringName) -> void:
	var card := _dragging_card
	var card_index := _dragging_card_index
	var card_data := _dragging_card_data.duplicate(true)
	_clear_card_drag()

	if target_entity_id != &"":
		_select_card_for_entity(target_entity_id, card_data)
	elif card != null and card_index >= 0:
		if card_index == _selected_card_index:
			if card_stack != null:
				card_stack._move_card_to_selection_slot(card, card_index, _get_player_entity_id(), true)
		else:
			if card_stack != null:
				card_stack._move_card_to_layout_position(card, card_index, true)

	_update_selection_slot_state()
	_update_slot_card_previews()


func _clear_card_drag() -> void:
	_dragging_card_index = -1
	_dragging_card = null
	_dragging_card_data = {}
	_drag_offset = Vector2.ZERO
	if card_stack != null:
		card_stack.set_dragging_card_index(-1)


func _get_card_stack_mouse_position() -> Vector2:
	return card_stack.get_mouse_position_in_hand() if card_stack != null else Vector2.ZERO


func _get_selection_slot_card_position(entity_id: StringName) -> Vector2:
	if selection_slots_view == null:
		return Vector2.ZERO

	return selection_slots_view.get_card_position(entity_id, card_stack)


func _get_hovered_selection_slot_entity_id() -> StringName:
	var selected_entity_id := _get_player_entity_id()
	if selected_entity_id == &"" or selection_slots_view == null:
		return &""

	return selection_slots_view.get_hovered_entity_id(selected_entity_id, get_global_mouse_position())


func _update_selection_slot_state() -> void:
	if selection_slots_view == null:
		return

	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {}) if state_store != null else {}
	selection_slots_view.update_state(_get_player_entity_id(), _dragging_card != null, selected_cards, get_global_mouse_position())


func _update_slot_card_previews() -> void:
	if state_store == null or selection_slots_view == null:
		return

	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {})
	selection_slots_view.update_slot_card_previews(selected_cards, _get_player_entity_id())


func _update_slot_card_preview_positions() -> void:
	if selection_slots_view != null:
		selection_slots_view.update_slot_card_preview_positions()



func _enqueue_card_action(card_data: Dictionary) -> void:
	var entity_id := _get_player_entity_id()
	if entity_id == &"":
		push_warning("Cannot enqueue card action before an entity is on the board.")
		return
	_enqueue_card_action_for(card_data, entity_id)


func _enqueue_card_action_for(card_data: Dictionary, entity_id: StringName) -> void:
	if action_queue == null:
		push_warning("Cannot enqueue card action without an ActionQueue.")
		return

	var action := _create_card_action(card_data, entity_id)
	if action.is_empty():
		push_warning("Cannot enqueue card without action data: %s." % card_data)
		return

	var batches := _create_ordered_action_batches_from_stack([action])
	for batch: Array in batches:
		action_queue.enQueue(batch)


func _create_ordered_action_batches_from_stack(action_stack: Array[Dictionary]) -> Array[Array]:
	if game_loop != null:
		return game_loop.create_ordered_action_batches(action_stack)

	# fallback: single batch
	var batches: Array[Array] = []
	batches.append(action_stack.duplicate())
	return batches


func _create_card_action(card_data: Dictionary, entity_id: StringName) -> Dictionary:
	if _card_action_factory == null:
		_card_action_factory = CardActionFactory.new(state_store)
	return _card_action_factory.create_card_action(card_data, entity_id)


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


func _layout_card_hand(animate_selected: bool = false) -> void:
	if card_stack != null:
		card_stack._layout_cards(animate_selected, _selected_card_index, _dragging_card_index)
