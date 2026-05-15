extends Control

const CARD_SIZE := Vector2(116.0, 158.0)
const CARD_OVERLAP_PIXELS := 34.0
const CARD_RAISE_PIXELS := 14.0
const CARD_HOVER_RAISE_PIXELS := 28.0
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
const ENTITY_CARD_POOL_SIZE := 5
const SELECTION_SLOT_SIZE := Vector2(150.0, 190.0)
const SELECTION_SLOT_LABEL_NAME := "SlotLabel"
const CARD_TITLE_LABEL_NAME := "TitleLabel"
const CARD_COST_LABEL_NAME := "CostLabel"
const CARD_BODY_LABEL_NAME := "BodyLabel"
const CARD_BACK_ENTITY_LABEL_NAME := "EntityLabel"
const CARD_COLORS := [
	Color(0.20, 0.28, 0.34, 1.0),
	Color(0.32, 0.24, 0.30, 1.0),
	Color(0.22, 0.34, 0.26, 1.0),
	Color(0.36, 0.30, 0.20, 1.0),
	Color(0.26, 0.26, 0.38, 1.0),
]

@export var action_queue_path: NodePath
@export var action_handler_path: NodePath
@export var state_store_path: NodePath
@export var game_loop_path: NodePath

@onready var card_stack: Control = $CardStackAnchor/CardStack
@onready var confirm_button: Button = $ConfirmButton
@onready var selection_slot_row: HBoxContainer = $SelectionSlots/DropZoneRow
@onready var selection_slot_template: PanelContainer = $SelectionSlots/DropZoneRow/DropZoneTemplate
@onready var card_templates_root: Control = $CardTemplates
@onready var card_face_template: Panel = $CardTemplates/CardFaceTemplate
@onready var card_back_template: Panel = $CardTemplates/CardBackTemplate
@onready var action_queue: Node = get_node_or_null(action_queue_path)
@onready var action_handler: Node = get_node_or_null(action_handler_path)
@onready var state_store: Node = get_node_or_null(state_store_path)
@onready var game_loop: Node = get_node_or_null(game_loop_path)

var _selection_slots: Dictionary = {}
var _slot_card_nodes: Dictionary = {}
var _card_tweens: Dictionary = {}
var _card_nodes: Array[Control] = []
var _selected_card_index: int = -1
var _dragging_card_index: int = -1
var _dragging_card: Control
var _dragging_card_data: Dictionary = {}
var _drag_offset := Vector2.ZERO
var _active_cards: Array[Dictionary] = []
var _pending_confirmed_card_actions: Dictionary = {}
var _pending_card_return_count := 0
var _cards: Array[Dictionary] = [
	{
		"title": "Bump",
		"body": "Deal damage",
		"action_factory": "bump",
		"args": { "damage_min": 1, "damage_max": 9 },
	},
	{
		"title": "Strong Bump",
		"body": "Heavy hit",
		"action_factory": "strong_bump",
		"args": { "resource": 3, "damage_min": 4, "damage_max": 9 },
	},
	{
		"title": "Throw",
		"body": "Ranged hit",
		"action_factory": "throw_projectile",
		"args": { "damage_min": 1, "damage_max": 9 },
	},
	{
		"title": "Focus",
		"body": "Gain focus",
		"action_factory": "focus",
		"args": { "value": 1 },
	},
	{
		"title": "Heal",
		"body": "Restore HP",
		"action_factory": "heal",
		"args": { "resource": 1, "value": 3 },
	},
	{
		"title": "Thunder",
		"body": "Hit target",
		"action_factory": "summon_thunder",
		"args": { "resource": 3, "value": 5 },
	},
	{
		"title": "Move Left",
		"body": "Step left",
		"action_factory": "move_left",
		"args": {},
	},
	{
		"title": "Move Right",
		"body": "Step right",
		"action_factory": "move_right",
		"args": {},
	},
]


func _ready() -> void:
	randomize()
	if selection_slot_template != null:
		selection_slot_template.visible = false
	if card_templates_root != null:
		card_templates_root.visible = false
	_sync_selection_slots()
	resized.connect(_update_slot_card_preview_positions)
	resized.connect(_layout_cards)
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


func _rebuild_cards() -> void:
	_card_nodes.clear()
	_clear_card_drag()
	for tween: Tween in _card_tweens.values():
		if tween:
			tween.kill()
	_card_tweens.clear()

	for child: Node in card_stack.get_children():
		card_stack.remove_child(child)
		child.queue_free()

	for index in _active_cards.size():
		var card := _create_card(_active_cards[index], index)
		card_stack.add_child(card)
		_card_nodes.append(card)

	_layout_cards()
	_update_card_enabled_states()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _create_card(card_data: Dictionary, index: int) -> Panel:
	var card := card_face_template.duplicate() as Panel if card_face_template != null else Panel.new()
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


func _get_card_cost_text(card_data: Dictionary) -> String:
	var args: Dictionary = card_data.get("args", card_data.get("action", {}).get("payload", {}).get("args", {}))
	var resource := int(args.get("resource", 0))
	return str(resource) if resource > 0 else ""


func _on_card_mouse_entered(card: Control, index: int) -> void:
	_tween_card_hover(card, index, true)


func _on_card_mouse_exited(card: Control, index: int) -> void:
	_tween_card_hover(card, index, false)


func _tween_card_hover(card: Control, index: int, is_hovered: bool) -> void:
	if card == null:
		return
	if index == _dragging_card_index or index == _selected_card_index:
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
		target_z_index = 100 + index

	_apply_fixed_card_size(card)
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
		_layout_cards(true)
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
	var focus := _get_player_focus()
	if confirm_button != null:
		var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {}) if state_store != null else {}
		confirm_button.disabled = not _has_unconfirmed_selected_card(selected_cards)
	for i in _card_nodes.size():
		var card := _card_nodes[i]
		if card == null:
			continue
		var args: Dictionary = _active_cards[i].get("args", {})
		var cost := int(args.get("resource", 0))
		var is_selected := i == _selected_card_index
		var is_affordable := focus >= cost
		var is_pending := _pending_confirmed_card_actions.has(_get_player_entity_id()) and is_selected
		if is_pending:
			card.modulate = Color(0.70, 0.70, 0.70, 0.85)
		elif is_selected:
			card.modulate = Color(1.0, 0.95, 0.55, 1.0)
		elif is_affordable:
			card.modulate = Color.WHITE
		else:
			card.modulate = Color(0.45, 0.45, 0.45, 0.65)


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

	_layout_cards(true)
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

	_layout_cards()
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
		if card_index < 0 or card_index >= _card_nodes.size():
			continue

		var card := _card_nodes[card_index]
		if card == null:
			continue

		animated_count += 1
		_pending_card_return_count += 1
		_float_card_back_to_hand(card, card_index, pending_entity_ids)

	if animated_count == 0:
		_clear_pending_cards_after_return(pending_entity_ids)


func _float_card_back_to_hand(card: Control, index: int, pending_entity_ids: Array[StringName]) -> void:
	if _card_tweens.has(card):
		var active_tween: Tween = _card_tweens[card]
		if active_tween:
			active_tween.kill()

	var card_count := _card_nodes.size()
	var centered_index := _get_card_centered_index(index, card_count)
	var target_position := _get_card_base_position(index, card_count)
	var target_rotation := centered_index * 4.0
	var target_z_index := index

	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	card.z_index = 220 + index

	var tween := create_tween()
	_card_tweens[card] = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_position, CARD_HOVER_SECONDS)
	tween.tween_property(card, "rotation_degrees", target_rotation, CARD_HOVER_SECONDS)
	tween.tween_property(card, "scale", Vector2.ONE, CARD_HOVER_SECONDS)
	tween.finished.connect(_on_pending_card_return_tween_finished.bind(card, tween, target_z_index, pending_entity_ids))


func _on_pending_card_return_tween_finished(card: Control, tween: Tween, target_z_index: int, pending_entity_ids: Array[StringName]) -> void:
	if _card_tweens.get(card, null) == tween:
		_card_tweens.erase(card)

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
	_layout_cards()
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
	_rebuild_cards()


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
	if state_store == null:
		return

	var entities: Dictionary = state_store.get_value(&"entities", {})
	for raw_entity_id: Variant in entities:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id == &"" or _selection_slots.has(entity_id):
			continue
		_selection_slots[entity_id] = _create_selection_slot(entity_id)

	var removed_entity_ids: Array[StringName] = []
	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		if not entities.has(entity_id):
			removed_entity_ids.append(entity_id)

	for entity_id: StringName in removed_entity_ids:
		var slot := _selection_slots[entity_id] as PanelContainer
		_selection_slots.erase(entity_id)
		if slot != null:
			slot.queue_free()
		_remove_slot_card_preview(entity_id)

	_update_slot_card_preview_positions()
	_update_selection_slot_state()
	_update_slot_card_previews()


func _create_selection_slot(entity_id: StringName) -> PanelContainer:
	var slot := selection_slot_template.duplicate() as PanelContainer if selection_slot_template != null else PanelContainer.new()
	slot.name = "DropZone_%s" % entity_id
	slot.custom_minimum_size = SELECTION_SLOT_SIZE
	slot.size = SELECTION_SLOT_SIZE
	slot.visible = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_slot_row.add_child(slot)
	_update_selection_slot_label(slot, entity_id, false)

	return slot


func _layout_selection_slots() -> void:
	_update_slot_card_preview_positions()


func _start_card_drag(card_data: Dictionary, index: int, card: Control) -> void:
	if card == null:
		return

	if _card_tweens.has(card):
		var active_tween: Tween = _card_tweens[card]
		if active_tween:
			active_tween.kill()

	_dragging_card_index = index
	_dragging_card = card
	_dragging_card_data = card_data
	_drag_offset = _get_card_stack_mouse_position() - card.position
	_apply_fixed_card_size(card)
	card.rotation_degrees = 0.0
	card.scale = Vector2.ONE
	card.z_index = 300 + index
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
			_move_card_to_selection_slot(card, card_index, _get_player_entity_id(), true)
		else:
			_move_card_to_layout_position(card, card_index, true)

	_update_selection_slot_state()
	_update_slot_card_previews()


func _clear_card_drag() -> void:
	_dragging_card_index = -1
	_dragging_card = null
	_dragging_card_data = {}
	_drag_offset = Vector2.ZERO


func _move_card_to_layout_position(card: Control, index: int, animated: bool) -> void:
	if card == null:
		return

	if _card_tweens.has(card):
		var active_tween: Tween = _card_tweens[card]
		if active_tween:
			active_tween.kill()

	var card_count := _card_nodes.size()
	var centered_index := _get_card_centered_index(index, card_count)
	var target_position := _get_card_base_position(index, card_count)
	var target_rotation := centered_index * 4.0
	var target_z_index := index

	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	if animated:
		card.z_index = target_z_index
		var tween := create_tween()
		_card_tweens[card] = tween
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_position, CARD_HOVER_SECONDS)
		tween.tween_property(card, "rotation_degrees", target_rotation, CARD_HOVER_SECONDS)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_HOVER_SECONDS)
		tween.finished.connect(_on_card_hover_tween_finished.bind(card, tween, target_z_index))
	else:
		card.position = target_position
		card.rotation_degrees = target_rotation
		card.scale = Vector2.ONE
		card.z_index = target_z_index


func _move_card_to_selection_slot(card: Control, index: int, entity_id: StringName, animated: bool) -> void:
	if card == null:
		return

	if _card_tweens.has(card):
		var active_tween: Tween = _card_tweens[card]
		if active_tween:
			active_tween.kill()

	var target_position := _get_selection_slot_card_position(entity_id)
	var target_z_index := 150 + index
	_apply_fixed_card_size(card)
	card.pivot_offset = CARD_SIZE / 2.0
	if animated:
		card.z_index = target_z_index
		var tween := create_tween()
		_card_tweens[card] = tween
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_position, CARD_HOVER_SECONDS)
		tween.tween_property(card, "rotation_degrees", 0.0, CARD_HOVER_SECONDS)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_HOVER_SECONDS)
		tween.finished.connect(_on_card_hover_tween_finished.bind(card, tween, target_z_index))
	else:
		card.position = target_position
		card.rotation_degrees = 0.0
		card.scale = Vector2.ONE
		card.z_index = target_z_index


func _get_card_stack_mouse_position() -> Vector2:
	return card_stack.get_global_transform_with_canvas().affine_inverse() * get_global_mouse_position()


func _get_selection_slot_card_position(entity_id: StringName) -> Vector2:
	var slot := _selection_slots.get(entity_id, null) as PanelContainer
	if slot == null:
		return Vector2.ZERO

	var slot_center := slot.get_global_rect().get_center()
	var local_center := card_stack.get_global_transform_with_canvas().affine_inverse() * slot_center
	return local_center - CARD_SIZE / 2.0


func _get_hovered_selection_slot_entity_id() -> StringName:
	var selected_entity_id := _get_player_entity_id()
	if selected_entity_id == &"":
		return &""

	var mouse_position := get_global_mouse_position()
	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id != selected_entity_id:
			continue

		var slot := _selection_slots[raw_entity_id] as PanelContainer
		if slot != null and slot.get_global_rect().has_point(mouse_position):
			return entity_id

	return &""


func _update_selection_slot_state() -> void:
	if _selection_slots.is_empty():
		return

	var hovered_entity_id := _get_hovered_selection_slot_entity_id() if _dragging_card != null else &""
	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {}) if state_store != null else {}
	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		var slot := _selection_slots[raw_entity_id] as PanelContainer
		if slot == null:
			continue

		slot.modulate = Color.WHITE
		if hovered_entity_id == entity_id:
			slot.modulate = Color(0.72, 1.0, 0.72, 1.0)
		elif _dragging_card != null and entity_id != _get_player_entity_id():
			slot.modulate = Color(0.50, 0.50, 0.50, 0.65)
		elif selected_cards.has(entity_id):
			slot.modulate = Color(1.0, 0.94, 0.54, 1.0)
		_update_selection_slot_label(slot, entity_id, selected_cards.has(entity_id))


func _get_selection_slot_entity_ids() -> Array[StringName]:
	var entity_ids: Array[StringName] = []
	for raw_entity_id: Variant in _selection_slots:
		entity_ids.append(StringName(str(raw_entity_id)))
	entity_ids.sort()
	return entity_ids


func _update_selection_slot_label(slot: PanelContainer, entity_id: StringName, has_selected_card: bool) -> void:
	var label := slot.find_child(SELECTION_SLOT_LABEL_NAME, true, false) as Label
	if label == null:
		return

	label.text = "%s\n%s" % [entity_id, "Ready" if has_selected_card else "Drop"]


func _update_slot_card_previews() -> void:
	if state_store == null:
		return

	var selected_cards: Dictionary = state_store.get_value(&"selected_cards", {})
	var current_entity_id := _get_player_entity_id()
	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id == current_entity_id:
			_remove_slot_card_preview(entity_id)
			continue

		var card_data: Dictionary = selected_cards.get(entity_id, {})
		if card_data.is_empty():
			_remove_slot_card_preview(entity_id)
			continue

		_set_slot_card_preview(entity_id, card_data)

	var removed_entity_ids: Array[StringName] = []
	for raw_entity_id: Variant in _slot_card_nodes:
		var entity_id := StringName(str(raw_entity_id))
		if not _selection_slots.has(entity_id) or not selected_cards.has(entity_id):
			removed_entity_ids.append(entity_id)

	for entity_id: StringName in removed_entity_ids:
		_remove_slot_card_preview(entity_id)

	_update_slot_card_preview_positions()


func _set_slot_card_preview(entity_id: StringName, card_data: Dictionary) -> void:
	var preview := _slot_card_nodes.get(entity_id, null) as Control
	if preview != null and preview.get_meta(&"card_data", {}) == card_data:
		return

	_remove_slot_card_preview(entity_id)
	preview = _create_slot_card_preview(entity_id, card_data)
	preview.set_meta(&"card_data", card_data.duplicate(true))
	add_child(preview)
	_slot_card_nodes[entity_id] = preview


func _remove_slot_card_preview(entity_id: StringName) -> void:
	var preview := _slot_card_nodes.get(entity_id, null) as Control
	_slot_card_nodes.erase(entity_id)
	if preview != null:
		preview.queue_free()


func _create_slot_card_preview(entity_id: StringName, _card_data: Dictionary) -> Panel:
	var card := card_back_template.duplicate() as Panel if card_back_template != null else Panel.new()
	card.name = "CardBack_%s" % entity_id
	_apply_fixed_card_size(card)
	card.visible = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 140
	_set_label_text(card, CARD_BACK_ENTITY_LABEL_NAME, str(entity_id))

	return card


func _update_slot_card_preview_positions() -> void:
	for raw_entity_id: Variant in _slot_card_nodes:
		var entity_id := StringName(str(raw_entity_id))
		var preview := _slot_card_nodes[raw_entity_id] as Control
		if preview == null:
			continue

		_apply_fixed_card_size(preview)
		preview.position = _get_selection_slot_card_preview_position(entity_id)
		preview.rotation_degrees = 0.0
		preview.scale = Vector2.ONE
		preview.z_index = 140


func _get_selection_slot_card_preview_position(entity_id: StringName) -> Vector2:
	var slot := _selection_slots.get(entity_id, null) as PanelContainer
	if slot == null:
		return Vector2.ZERO

	var slot_center := slot.get_global_rect().get_center()
	var local_center := get_global_transform_with_canvas().affine_inverse() * slot_center
	return local_center - CARD_SIZE / 2.0



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
	var action_factory := str(card_data.get("action_factory", ""))
	if action_factory != "":
		return _create_action_from_factory(action_factory, entity_id, card_data.get("args", {}))

	push_warning("Card has no action_factory: %s." % card_data)
	return {}


func _create_action_from_factory(action_factory: String, entity_id: StringName, args: Dictionary = {}) -> Dictionary:
	match action_factory:
		"bump":
			return _create_attack_action(
				entity_id,
				"bump",
				_get_vector_to_target(entity_id, 1),
				randi_range(int(args.get("damage_min", BUMP_DAMAGE_MIN)), int(args.get("damage_max", BUMP_DAMAGE_MAX)))
			)
		"strong_bump":
			return _create_attack_action(
				entity_id,
				"strong_bump",
				_get_vector_to_target(entity_id, int(args.get("vector_length", STRONG_BUMP_VECTOR_LENGTH))),
				randi_range(int(args.get("damage_min", STRONG_BUMP_DAMAGE_MIN)), int(args.get("damage_max", STRONG_BUMP_DAMAGE_MAX))),
				int(args.get("resource", STRONG_BUMP_FOCUS_COST))
			)
		"throw_projectile":
			var source_cell := _get_entity_board_cell(entity_id)
			var target_cell := _get_first_other_board_cell(entity_id)
			var actual_length := 2
			if source_cell != Vector2i(-1, -1) and target_cell != Vector2i(-1, -1):
				var delta := target_cell - source_cell
				actual_length = clampi(maxi(absi(delta.x), absi(delta.y)), 2, 5)
			return _create_attack_action(
				entity_id,
				"throw_projectile",
				_get_vector_to_target(entity_id, actual_length),
				randi_range(int(args.get("damage_min", THROW_PROJECTILE_DAMAGE_MIN)), int(args.get("damage_max", THROW_PROJECTILE_DAMAGE_MAX))),
				int(args.get("resource", THROW_PROJECTILE_RESOURCE_COST))
			)
		"focus":
			return _create_cast_action(entity_id, "focus", args)
		"heal":
			return _create_cast_action(entity_id, "heal", args)
		"summon_thunder":
			return _create_cast_action(entity_id, "summon_thunder", args)
		"move_left":
			return _create_move_action(entity_id, Vector2i.LEFT)
		"move_right":
			return _create_move_action(entity_id, Vector2i.RIGHT)
		_:
			push_warning("Unsupported card action factory: %s." % action_factory)
			return {}


func _create_cast_action(entity_id: StringName, cast_type: String, args: Dictionary) -> Dictionary:
	var cast_args := {
		"type": cast_type,
		"source": "hand_gui",
	}
	if args.has("value"):
		cast_args["value"] = int(args["value"])
	if args.has("resource"):
		cast_args["resource"] = int(args["resource"])
	return {
		"eventName": "perform_cast",
		"payload": {
			"id": entity_id,
			"args": cast_args,
		},
	}


func _create_move_action(entity_id: StringName, vector: Vector2i) -> Dictionary:
	return {
		"eventName": "move_entity",
		"payload": {
			"id": entity_id,
			"vector": vector,
		},
	}


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


func _layout_cards(animate_selected: bool = false) -> void:
	if card_stack == null:
		return

	var card_count := card_stack.get_child_count()
	if card_count == 0:
		return

	card_stack.size = Vector2.ZERO

	for index in card_count:
		var card := card_stack.get_child(index) as Control
		if index == _dragging_card_index:
			continue
		if index == _selected_card_index:
			_move_card_to_selection_slot(card, index, _get_player_entity_id(), animate_selected)
			continue

		var centered_index := _get_card_centered_index(index, card_count)
		_apply_fixed_card_size(card)
		card.pivot_offset = CARD_SIZE / 2.0
		card.position = _get_card_base_position(index, card_count)
		card.rotation_degrees = centered_index * 4.0


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
