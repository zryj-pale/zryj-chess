extends Node3D

@export var typ: String
@export var kolor: String

# Node3D has no modulate of its own (that's a CanvasItem/2D concept) - forward
# it to the sprite, so callers that tint a whole figura (e.g. the gray army-
# creator preview) don't need to know it's actually a Sprite3D underneath.
var modulate: Color = Color.WHITE:
	set(value):
		modulate = value
		$tekstura.modulate = value

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


func promocja(typ_figury):
	typ = typ_figury
	$tekstura.region_rect = WSPOLRZEDNE_SPRITE[NAZWY[typ+kolor]]
