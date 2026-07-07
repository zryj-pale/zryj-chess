extends Control

var przycisk_nacisniety = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$relay.connect_to_server("ws://31.70.109.158:607")
	$relay.join_room("rapists room")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_check_button_button_up() -> void:
	przycisk_nacisniety = true

func _on_check_button_button_down() -> void:
	przycisk_nacisniety = false
