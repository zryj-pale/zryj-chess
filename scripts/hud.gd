extends CanvasLayer

@onready var bialy_label = $BialyLabel
@onready var czarny_label = $CzarnyLabel

func _process(_delta):
    var main = get_tree().get_first_node_in_group("game_main")
    if main:
        bialy_label.text = "Biale: " + str(main.bialy_tiles)
        czarny_label.text = "Czarne: " + str(main.czarny_tiles)
        if main.kolor_posuniecia == "b":
            bialy_label.modulate = Color.WHITE
            czarny_label.modulate = Color.GRAY
        else:
            bialy_label.modulate = Color.GRAY
            czarny_label.modulate = Color.WHITE