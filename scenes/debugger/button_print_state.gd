extends Button

@onready var state_store: Node = $"../../BattleStateStore"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	print("battle state store: ", state_store.get_state())
