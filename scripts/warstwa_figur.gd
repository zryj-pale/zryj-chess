class_name WarstwaFigur
extends TextureRect

# ── Dlaczego figura jest rysowana w osobnej warstwie ────────────────────────
#
# Rozpikselowanie to operacja NA OBRAZIE: trzeba go zrasteryzować w małej
# rozdzielczości i powiększyć bez wygładzania. Shader przestrzenny tego nie
# zrobi - działa per fragment pełnej rasteryzacji, więc spłaszczy kolor, ale
# nigdy nie zrobi schodków na sylwetce (próba z vertex snappingiem i ditheringiem
# skończyła się samymi kropkami).
#
# Dopóki figura była płaskim obrazkiem, wystarczyło piec ją do własnego bufora.
# Prawdziwa bryła stojąca na planszy tego nie może: musi być widziana pod kątem
# planszy, mieć głębię i zasłanianie przez kafelki, więc nie da się jej spłaszczyć
# do jednego quadu.
#
# Rozwiązanie: ta sama sztuczka, którą shader napisów w menu robi na swoim
# kontenerze - cała warstwa figur jest renderowana w małej rozdzielczości
# (PIKSELE_NA_KRATKE na kratkę planszy) i powiększana filtrem nearest.
#
# DWA WARUNKI, oba wykryte pomiarem, nie założone:
#
#  1. Viewport warstwy musi być ZAGNIEŻDŻONY w viewporcie planszy i dziedziczyć
#     jego świat (own_world_3d = false). Przypisanie `world_3d` wprost nie
#     działa: viewport renderuje wtedy własny, pusty świat - zmierzone, warstwa
#     miała 0 pikseli i pokazywała tylko to, co dodano jej bezpośrednio.
#  2. Cień figury na kafelku wymaga osobnej, nie rysowanej kopii bryły na
#     warstwie planszy (SHADOWS_ONLY). Pass cieni widoku planszy respektuje
#     maskę jego kamery, która warstwę figur wyklucza.
#
# Kamera planszy ma warstwę figur wykluczoną, więc figury nie są rysowane dwa
# razy.

const PIKSELE_NA_KRATKE := 32 # pikseli figury na jedną kratkę planszy
const WARSTWA_FIGUR := 2 # warstwa 3D, na której stoją figury

var _plansza: SubViewport
var _kamera_planszy: Camera3D
var _kontener_planszy: Control
var _podglad: SubViewport
var _kamera: Camera3D

func setup(plansza: SubViewport, kamera_planszy: Camera3D, kontener_planszy: Control,
		podglad: SubViewport, kamera: Camera3D) -> void:
	_plansza = plansza
	_kamera_planszy = kamera_planszy
	_kontener_planszy = kontener_planszy
	_podglad = podglad
	_kamera = kamera

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	z_index = 1

	_podglad.transparent_bg = true
	# Dziedziczy świat planszy, bo jest w niej zagnieżdżony w drzewie.
	_podglad.own_world_3d = false
	_podglad.handle_input_locally = false
	_podglad.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_podglad.msaa_3d = Viewport.MSAA_DISABLED
	texture = _podglad.get_texture()

	_kamera.cull_mask = 1 << (WARSTWA_FIGUR - 1)
	_kamera.current = true

	if kamera_planszy != null:
		kamera_planszy.cull_mask &= ~(1 << (WARSTWA_FIGUR - 1))

func _process(_delta: float) -> void:
	odswiez()

func odswiez() -> void:
	if _plansza == null or _kamera_planszy == null or _podglad == null:
		return
	_synchronizuj_kamere()
	_ustaw_rozmiar()

func _synchronizuj_kamere() -> void:
	_kamera.global_transform = _kamera_planszy.global_transform
	_kamera.projection = _kamera_planszy.projection
	_kamera.fov = _kamera_planszy.fov
	_kamera.size = _kamera_planszy.size
	_kamera.keep_aspect = _kamera_planszy.keep_aspect
	_kamera.near = _kamera_planszy.near
	_kamera.far = _kamera_planszy.far

# Rozmiar warstwy liczy się z tego, ile pikseli ma kratka planszy, a nie ze
# stałej liczby - inaczej rozmiar piksela figury zmieniałby się razem z oknem.
# Źródłem prawdy jest sama kamera planszy, więc nie da się tego rozjechać
# z kadrowaniem.
func kratka_w_pikselach() -> float:
	var a := _kamera_planszy.unproject_position(Vector3.ZERO)
	var b := _kamera_planszy.unproject_position(Vector3(1.0, 0.0, 0.0))
	return a.distance_to(b)

func _ustaw_rozmiar() -> void:
	var kratka := kratka_w_pikselach()
	if kratka <= 0.0:
		return
	var skala := float(PIKSELE_NA_KRATKE) / kratka # pikseli warstwy na piksel planszy
	_podglad.size = Vector2i(
		maxi(1, roundi(float(_plansza.size.x) * skala)),
		maxi(1, roundi(float(_plansza.size.y) * skala)))

	# Rect dokładnie tam, gdzie widać planszę. Kontener planszy jest przeskalowany
	# w dół (Viewport3D.fit_to_pixels), więc bierzemy jego pole PO skalowaniu.
	if _kontener_planszy != null:
		position = _kontener_planszy.position
		size = _kontener_planszy.size * _kontener_planszy.scale
