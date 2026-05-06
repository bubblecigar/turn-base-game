extends Button

@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	print("state store: ", state_store.get_state())
