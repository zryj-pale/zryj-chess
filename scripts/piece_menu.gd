extends HBoxContainer

signal piece_selected(typ: String)

var piece_buttons = []

func _ready():
    create_menu()

func create_menu():
    for child in get_children():
        child.queue_free()
    piece_buttons.clear()
    
    var pieces = ["P", "S", "G", "W", "H", "K"]
    var piece_names = {
        "P": "Pionek",
        "S": "Skoczek", 
        "G": "Goniec",
        "W": "Wieża",
        "H": "Hetman",
        "K": "Król"
    }
    
    for piece in pieces:
        var btn = Button.new()
        btn.text = piece_names[piece]
        btn.custom_minimum_size = Vector2(80, 40)
        btn.pressed.connect(_on_piece_pressed.bind(piece))
        add_child(btn)
        piece_buttons.append(btn)

func _on_piece_pressed(typ: String):
    piece_selected.emit(typ)
