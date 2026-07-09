extends Control

var przycisk_nacisniety = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$relay.connect_to_server("ws://31.70.109.158:607")
	$relay.join_room("rapists room")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if przycisk_nacisniety:
		$relay.send_message($"room name".text)

func przycisk_wlaczon(toggled_on: bool) -> void:
	przycisk_nacisniety = toggled_on

func _on_relay_message_received(text: String) -> void:
	$Label.text = text
