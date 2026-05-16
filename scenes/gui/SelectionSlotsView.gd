extends Control

const CARD_BACK_ENTITY_LABEL_NAME := "EntityLabel"
const SELECTION_SLOT_LABEL_NAME := "SlotLabel"
const SELECTION_SLOT_SIZE := Vector2(150.0, 190.0)

@onready var selection_slot_row: HBoxContainer = $DropZoneRow
@onready var selection_slot_template: PanelContainer = $DropZoneRow/DropZoneTemplate

var _selection_slots: Dictionary = {}
var _slot_card_nodes: Dictionary = {}
var _state_store: Node
var _card_back_template: Panel
var _preview_root: Control
var _card_size := Vector2(116.0, 158.0)


func setup(state_store: Node, card_back_template: Panel, preview_root: Control, card_size: Vector2) -> void:
	_state_store = state_store
	_card_back_template = card_back_template
	_preview_root = preview_root
	_card_size = card_size
	if selection_slot_template != null:
		selection_slot_template.visible = false


func sync_slots() -> void:
	if _state_store == null:
		return

	var entities: Dictionary = _state_store.get_value(&"entities", {})
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

	update_slot_card_preview_positions()


func update_state(selected_entity_id: StringName, is_dragging: bool, selected_cards: Dictionary, mouse_position: Vector2) -> void:
	if _selection_slots.is_empty():
		return

	var hovered_entity_id := get_hovered_entity_id(selected_entity_id, mouse_position) if is_dragging else &""
	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		var slot := _selection_slots[raw_entity_id] as PanelContainer
		if slot == null:
			continue

		slot.modulate = Color.WHITE
		if hovered_entity_id == entity_id:
			slot.modulate = Color(0.72, 1.0, 0.72, 1.0)
		elif is_dragging and entity_id != selected_entity_id:
			slot.modulate = Color(0.50, 0.50, 0.50, 0.65)
		elif selected_cards.has(entity_id):
			slot.modulate = Color(1.0, 0.94, 0.54, 1.0)
		_update_selection_slot_label(slot, entity_id, selected_cards.has(entity_id))


func update_slot_card_previews(selected_cards: Dictionary, current_entity_id: StringName) -> void:
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

	update_slot_card_preview_positions()


func update_slot_card_preview_positions() -> void:
	for raw_entity_id: Variant in _slot_card_nodes:
		var entity_id := StringName(str(raw_entity_id))
		var preview := _slot_card_nodes[raw_entity_id] as Control
		if preview == null:
			continue

		_apply_fixed_card_size(preview)
		preview.position = get_card_preview_position(entity_id)
		preview.rotation_degrees = 0.0
		preview.scale = Vector2.ONE
		preview.z_index = 140


func get_hovered_entity_id(selected_entity_id: StringName, mouse_position: Vector2) -> StringName:
	if selected_entity_id == &"":
		return &""

	for raw_entity_id: Variant in _selection_slots:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id != selected_entity_id:
			continue

		var slot := _selection_slots[raw_entity_id] as PanelContainer
		if slot != null and slot.get_global_rect().has_point(mouse_position):
			return entity_id

	return &""


func get_card_position(entity_id: StringName, target_space: Control) -> Vector2:
	var slot := _selection_slots.get(entity_id, null) as PanelContainer
	if slot == null or target_space == null:
		return Vector2.ZERO

	var slot_center := slot.get_global_rect().get_center()
	var local_center := target_space.get_global_transform_with_canvas().affine_inverse() * slot_center
	return local_center - _card_size / 2.0


func get_card_preview_position(entity_id: StringName) -> Vector2:
	return get_card_position(entity_id, _preview_root)


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


func _update_selection_slot_label(slot: PanelContainer, entity_id: StringName, has_selected_card: bool) -> void:
	var label := slot.find_child(SELECTION_SLOT_LABEL_NAME, true, false) as Label
	if label == null:
		return

	label.text = "%s\n%s" % [entity_id, "Ready" if has_selected_card else "Drop"]


func _set_slot_card_preview(entity_id: StringName, card_data: Dictionary) -> void:
	var preview := _slot_card_nodes.get(entity_id, null) as Control
	if preview != null and preview.get_meta(&"card_data", {}) == card_data:
		return

	_remove_slot_card_preview(entity_id)
	preview = _create_slot_card_preview(entity_id)
	preview.set_meta(&"card_data", card_data.duplicate(true))
	if _preview_root != null:
		_preview_root.add_child(preview)
	_slot_card_nodes[entity_id] = preview


func _remove_slot_card_preview(entity_id: StringName) -> void:
	var preview := _slot_card_nodes.get(entity_id, null) as Control
	_slot_card_nodes.erase(entity_id)
	if preview != null:
		preview.queue_free()


func _create_slot_card_preview(entity_id: StringName) -> Panel:
	var card := _card_back_template.duplicate() as Panel if _card_back_template != null else Panel.new()
	card.name = "CardBack_%s" % entity_id
	_apply_fixed_card_size(card)
	card.visible = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 140
	_set_label_text(card, CARD_BACK_ENTITY_LABEL_NAME, str(entity_id))

	return card


func _apply_fixed_card_size(card: Control) -> void:
	if card == null:
		return

	card.custom_minimum_size = _card_size
	card.size = _card_size
	card.scale = Vector2.ONE


func _set_label_text(root: Node, label_name: String, text: String) -> void:
	var label := root.find_child(label_name, true, false) as Label
	if label == null:
		return

	label.text = text
