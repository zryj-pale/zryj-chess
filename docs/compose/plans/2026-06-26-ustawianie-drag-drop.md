# Ustawianie Drag-and-Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace text field input with drag-and-drop piece placement from a horizontal menu bar

**Architecture:** Add a menu bar scene with piece buttons, implement drag-and-drop logic, and update the setup scene to use the new interface

**Tech Stack:** Godot 4.7, GDScript

---

### Task 1: Create piece menu script

**Covers:** Piece menu creation

**Files:**
- Create: `scripts/piece_menu.gd`

**Interfaces:**
- Consumes: `kolor_posuniecia` from ustawianie.gd
- Produces: menu with draggable piece buttons

- [ ] **Step 1: Create piece_menu.gd script**

Create `scripts/piece_menu.gd`:

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/piece_menu.gd
git commit -m "feat: create piece menu script"
```

---

### Task 2: Create piece menu scene

**Covers:** Piece menu scene

**Files:**
- Create: `scenes/piece_menu.tscn`

**Interfaces:**
- Consumes: piece_menu.gd from Task 1
- Produces: menu scene to add to ustawianie.tscn

- [ ] **Step 1: Create piece_menu.tscn scene**

Create `scenes/piece_menu.tscn`:

```
[gd_scene load_steps=2 format=4 uid="uid://piecemenu01"]

[ext_resource type="Script" path="res://scripts/piece_menu.gd" id="1_menu"]

[node name="PieceMenu" type="HBoxContainer"]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -60.0
grow_horizontal = 2
grow_vertical = 0
script = ExtResource("1_menu")
```

- [ ] **Step 2: Commit**

```bash
git add scenes/piece_menu.tscn
git commit -m "feat: create piece menu scene"
```

---

### Task 3: Update ustawianie.gd for drag-and-drop

**Covers:** Drag-and-drop logic

**Files:**
- Modify: `scripts/ustawianie.gd`

**Interfaces:**
- Consumes: piece_selected signal from piece_menu
- Produces: pieces placed on board via drag

- [ ] **Step 1: Add drag-and-drop variables and state**

Add after line 30 (`var wybrana = null`):

```gdscript
var dragging = false
var drag_piece_type = null
var drag_preview = null
```

- [ ] **Step 2: Add piece_selected handler**

Add after `_ready` function:

```gdscript
func _on_piece_selected(typ: String):
    drag_piece_type = typ
    dragging = true
    create_drag_preview(typ)

func create_drag_preview(typ: String):
    if drag_preview:
        drag_preview.queue_free()
    drag_preview = preload("res://scenes/figura.tscn").instantiate()
    drag_preview.typ = typ
    drag_preview.kolor = kolor_posuniecia
    drag_preview.top_level = true
    drag_preview.modulate = Color(1, 1, 1, 0.7)
    add_child(drag_preview)

func _process(_delta: float) -> void:
    if dragging and drag_preview:
        drag_preview.global_position = get_global_mouse_position()
    
    var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
    if Input.is_action_just_pressed("mouse_click") and not dragging:
        var figura = najechana_figura()
        if figura and figura.kolor == kolor_posuniecia:
            usun_figure(figura)
```

- [ ] **Step 3: Add mouse click handling for placement**

Add after `_process` function:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if dragging:
            var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
            if pole_na_planszy(wskazane_pole) and stoi_figura(wskazane_pole) == null:
                dodaj(drag_piece_type, kolor_posuniecia, wskazane_pole)
                zapisz_figure(drag_piece_type, wskazane_pole)
            dragging = false
            drag_piece_type = null
            if drag_preview:
                drag_preview.queue_free()
                drag_preview = null
```

- [ ] **Step 4: Add piece removal function**

Add after `usun_figure` function:

```gdscript
func usun_figure(figura):
    var pole = pozycja(figura)
    usun_z_pamieci(figura.typ, pole)
    figury.erase(figura)
    figura.queue_free()
    $dzwiek/zakaz.play()

func usun_z_pamieci(typ: String, pole: Vector2i):
    if kolor_posuniecia == "b":
        for i in range(PozycjaOsobista.ustawienia_bialych.size() - 1, -1, -1):
            var ustawienie = PozycjaOsobista.ustawienia_bialych[i]
            if ustawienie[0] == typ and ustawienie[1] == pole:
                PozycjaOsobista.ustawienia_bialych.remove_at(i)
                break
    else:
        for i in range(PozycjaOsobista.ustawienia_czarnych.size() - 1, -1, -1):
            var ustawienie = PozycjaOsobista.ustawienia_czarnych[i]
            if ustawienie[0] == typ and ustawienie[1] == pole:
                PozycjaOsobista.ustawienia_czarnych.remove_at(i)
                break

func zapisz_figure(typ: String, pole: Vector2i):
    if kolor_posuniecia == "b":
        PozycjaOsobista.ustawienia_bialych.append([typ, pole])
    else:
        PozycjaOsobista.ustawienia_czarnych.append([typ, pole])
```

- [ ] **Step 5: Update synchronizacja to update menu**

Update `synchronizacja` function:

```gdscript
func synchronizacja():
    reset()
    if kolor_posuniecia == "b":
        for figura in PozycjaOsobista.ustawienia_bialych:
            dodaj(figura[0], "b", figura[1])
    else:
        for figura in PozycjaOsobista.ustawienia_czarnych:
            dodaj(figura[0], "c", figura[1])
    $PieceMenu.create_menu()
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ustawianie.gd
git commit -m "feat: add drag-and-drop logic to ustawianie"
```

---

### Task 4: Update ustawianie.tscn scene

**Covers:** Scene integration

**Files:**
- Modify: `scenes/ustawianie.tscn`

**Interfaces:**
- Consumes: piece_menu.tscn from Task 2
- Produces: updated scene with menu bar

- [ ] **Step 1: Add piece menu instance to scene**

Add to `scenes/ustawianie.tscn`:

```
[ext_resource type="PackedScene" uid="uid://piecemenu01" path="res://scenes/piece_menu.tscn" id="8_menu"]
```

And at the end:

```
[node name="PieceMenu" parent="." instance=ExtResource("8_menu")]
```

- [ ] **Step 2: Remove LineEdit node**

Delete the LineEdit node and its connection from the scene file.

- [ ] **Step 3: Connect piece_selected signal**

Add connection:

```
[connection signal="piece_selected" from="PieceMenu" to="." method="_on_piece_selected"]
```

- [ ] **Step 4: Commit**

```bash
git add scenes/ustawianie.tscn
git commit -m "feat: integrate piece menu into ustawianie scene"
```

---

### Task 5: Update reset function

**Covers:** Reset functionality

**Files:**
- Modify: `scripts/ustawianie.gd`

**Interfaces:**
- Consumes: existing reset logic
- Produces: updated reset that also clears black pieces

- [ ] **Step 1: Update _on_reset_pressed to clear both colors**

Update `_on_reset_pressed` function:

```gdscript
func _on_reset_pressed() -> void:
    reset()
    PozycjaOsobista.ustawienia_bialych.clear()
    PozycjaOsobista.ustawienia_czarnych.clear()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ustawianie.gd
git commit -m "feat: update reset to clear both piece colors"
```

---

### Task 6: Verify implementation

**Covers:** Testing

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: all previous tasks
- Produces: passing verification

- [ ] **Step 1: Run Godot headless to check for parse errors**

```bash
cd /Users/konrad/zryj-chess-main
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/ustawianie.gd 2>&1 | head -20
```

Expected: No parse errors

- [ ] **Step 2: Verify scene loads**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --check-only 2>&1
```

Expected: No errors

- [ ] **Step 3: Mark task T2 as done**

```bash
# Verification complete
```
