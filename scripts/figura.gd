extends Node3D

@export var typ: String
@export var kolor: String

# Modele stoją podstawą na kafelku. Ich rzeczywisty widok perspektywiczny
# jest renderowany w 80×80, także podczas ruchu.
const TYP_Z_MODELEM := "S" # na razie tylko skoczek ma modele
const PIECE_Y := 0.5 # main.gd/ustawianie.gd stawiają figurę pół kratki nad płytą
const MODEL_SPRITE := preload("res://scripts/piece_pixel_render.gd")

# Node3D nie ma własnego modulate; kolor przekazujemy gotowym sprite'om.
var modulate: Color = Color.WHITE:
	get:
		return _modulate
	set(value):
		_modulate = value
		_odswiez_zabarwienie()

var _modulate := Color.WHITE

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

var _model_sprite: Sprite3D

func _ready() -> void:
	_posadz_modele()
	_zastosuj_typ()

# Pozycja figury jest tym, co czyta logika szachowa, więc dryf płyty nie może jej
# ruszać - dlatego przesuwa się tylko zawartość.
func ustaw_lewitacje(offset: Vector3, tile_basis := Basis.IDENTITY) -> void:
	# Rotate around the foot, half a tile below the logical piece origin.
	var pivot := Vector3(0, -PIECE_Y, 0)
	var orientation := tile_basis if model_dla(typ, kolor) != null else Basis.IDENTITY
	($Zawartosc as Node3D).transform = Transform3D(orientation, offset + pivot - orientation * pivot)

func promocja(typ_figury) -> void:
	typ = typ_figury
	_zastosuj_typ()

func _modele() -> Array[Node3D]:
	return [$Zawartosc/SkoczekBialy, $Zawartosc/SkoczekCzarny]

# Czarny kolor dostaje model czarny, każdy inny biały - figura nigdy nie zostaje
# bez bryły, nawet gdyby kiedyś doszedł typ bez własnego modelu.
func model_dla(typ_figury: String, kolor_figury: String) -> Node3D:
	if typ_figury != TYP_Z_MODELEM:
		return null
	return $Zawartosc/SkoczekCzarny if kolor_figury == "c" else $Zawartosc/SkoczekBialy

func _zastosuj_typ() -> void:
	var model := model_dla(typ, kolor)
	for wezel in _modele():
		wezel.visible = false
	if _model_sprite != null:
		_model_sprite.visible = false
		_model_sprite.queue_free()
		_model_sprite = null
	if model != null:
		_model_sprite = MODEL_SPRITE.new()
		$Zawartosc.add_child(_model_sprite)
		_model_sprite.configure(model)
	($Zawartosc/tekstura as Sprite3D).visible = model == null
	if model == null:
		var nazwa: String = NAZWY.get(typ + kolor, NAZWY["Pb"])
		($Zawartosc/tekstura as Sprite3D).region_rect = WSPOLRZEDNE_SPRITE[nazwa]
	_ustaw_cien(model)
	_odswiez_zabarwienie()

# Origin modelu nie leży w jego stopach, więc figura postawiona na PIECE_Y
# wisiałaby pół kratki nad swoim polem. Mierzone z bryły i wyrównywane dla
# każdego modelu osobno, żeby podmiana modelu nie przesuwała figury.
func _posadz_modele() -> void:
	for model in _modele():
		var dol := INF
		var gora := -INF
		var punkty: Array[Vector3] = []
		for siatka in _siatki(model):
			var wzgledem: Transform3D = global_transform.affine_inverse() * siatka.global_transform
			for surface in siatka.mesh.get_surface_count():
				var vertices: PackedVector3Array = siatka.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var punkt: Vector3 = wzgledem * vertex
					punkty.append(punkt)
					dol = minf(dol, punkt.y)
					gora = maxf(gora, punkt.y)
		if dol == INF:
			continue
		# The imported base is slightly uneven: its opposite edge is higher
		# than the lowest one. Include the bottom 5% of the model so the
		# footprint contains the entire plinth, not only its lowest edge.
		var base_height := (gora - dol) * 0.05
		var base_min := Vector2(INF, INF)
		var base_max := Vector2(-INF, -INF)
		for punkt in punkty:
			if punkt.y <= dol + base_height:
				base_min = base_min.min(Vector2(punkt.x, punkt.z))
				base_max = base_max.max(Vector2(punkt.x, punkt.z))
		var center := (base_min + base_max) * 0.5
		model.position -= Vector3(center.x, dol + PIECE_Y, center.y)

func _siatki(wezel: Node) -> Array[MeshInstance3D]:
	var wynik: Array[MeshInstance3D] = []
	for dziecko in wezel.get_children():
		if dziecko is MeshInstance3D:
			wynik.append(dziecko)
		wynik.append_array(_siatki(dziecko))
	return wynik

func _odswiez_zabarwienie() -> void:
	var sprite := get_node_or_null("Zawartosc/tekstura") as Sprite3D
	if sprite != null:
		sprite.modulate = _modulate
	if _model_sprite != null:
		_model_sprite.modulate = _modulate

# Cień rzuca niewidoczna kopia modelu, zamiast prostokąta sprite'a.
func _ustaw_cien(model: Node3D) -> void:
	var cien := $Zawartosc/Cien as Node3D
	for dziecko in cien.get_children():
		dziecko.queue_free()
	if model == null:
		return
	for siatka in _siatki(model):
		var kopia := MeshInstance3D.new()
		kopia.mesh = siatka.mesh
		kopia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		kopia.layers = 1
		cien.add_child(kopia)
		# Transformacja GLOBALNA, a nie lokalna mesha: mesh siedzi wewnątrz
		# modelu, który ma własną skalę 0.04, więc skopiowanie samego jego
		# transformu dawało cień 25 razy za duży - zalewał całą planszę.
		# Rodzicem jest Zawartość, więc kopia jedzie razem z lewitacją płyty.
		kopia.global_transform = siatka.global_transform
