extends Node2D

@export var typ:String
@export var pozycja:Vector2i
@export var kolor:String
@export var mysz = false
@export var warstwa = self.visibility_layer

@onready var kolizje = [
	$tekstura/Area2D/S,
	$tekstura/Area2D/P,
	$tekstura/Area2D/G,
	$tekstura/Area2D/W,
	$tekstura/Area2D/H,
	$tekstura/Area2D/Kb,
	$tekstura/Area2D/Kc]

const WSPOLRZEDNE_SPRITE = {
	"b_pionkler" : Rect2(0, 0, 64, 64),
	"b_skoczek" : Rect2(64, 0, 64, 64),
	"b_goniec" : Rect2(128, 0, 64, 64),
	"b_wieza" : Rect2(192, 0, 64, 64),
	"b_hetman" : Rect2(256, 0, 64, 64),
	"b_krol" : Rect2(320, 0, 64, 64),
	"c_pionkler" : Rect2(0, 64, 64, 64),
	"c_skoczek" : Rect2(64, 64, 64, 64),
	"c_goniec" : Rect2(128, 64, 64, 64),
	"c_wieza" : Rect2(192, 64, 64, 64),
	"c_hetman" : Rect2(256, 64, 64, 64),
	"c_krol" : Rect2(320, 64, 64, 64)
	}

const NAZWY = {
	"Sb":"b_skoczek",
	"Gb":"b_goniec",
	"Pb":"b_pionkler",
	"Wb":"b_wieza",
	"Hb":"b_hetman",
	"Kb":"b_krol",
	"Sc":"c_skoczek",
	"Gc":"c_goniec",
	"Pc":"c_pionkler",
	"Wc":"c_wieza",
	"Hc":"c_hetman",
	"Kc":"c_krol"
	}

func _ready() -> void:
	$tekstura.region_rect = WSPOLRZEDNE_SPRITE[NAZWY[typ+kolor]]
	ustaw_kolizje(typ)


func _on_area_2d_mouse_entered() -> void:
	mysz = true


func _on_area_2d_mouse_exited() -> void:
	mysz = false

func promocja(typ_figury):
	typ = typ_figury
	$tekstura.region_rect = WSPOLRZEDNE_SPRITE[NAZWY[typ+kolor]]
	ustaw_kolizje(typ)
	

func ustaw_kolizje(typ_figury):
	for kolizja in kolizje:
		kolizja.disabled = true
	match typ_figury:
		"S":
			$tekstura/Area2D/S.disabled = false
		"P":
			$tekstura/Area2D/P.disabled = false
		"B":
			$tekstura/Area2D/B.disabled = false
		"G":
			$tekstura/Area2D/G.disabled = false
		"W":
			$tekstura/Area2D/W.disabled = false
		"H":
			$tekstura/Area2D/H.disabled = false
		"K":
			$tekstura/Area2D/Kc.disabled = false
