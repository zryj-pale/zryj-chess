# Online Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add peer-to-peer online multiplayer using ENet with a lobby for hosting/joining games

**Architecture:** Create a NetworkManager autoload for ENet networking, add a lobby scene for connection UI, and modify main.gd to sync moves between host and client

**Tech Stack:** Godot 4.7, GDScript, ENetMultiplayerPeer

---

### Task 1: Create NetworkManager autoload

**Covers:** Networking core

**Files:**
- Create: `scripts/network_manager.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: none
- Produces: `host_game(port)`, `join_game(ip, port)`, `send_move(from, to)`, signals for connection events

- [ ] **Step 1: Create network_manager.gd**

Create `scripts/network_manager.gd`:

```gdscript
extends Node

signal player_connected
signal player_disconnected
signal game_started
signal move_received(from: Vector2i, to: Vector2i)

var peer = ENetMultiplayerPeer.new()
var is_host = false
var player_id = 0

func host_game(port: int = 7777):
    var err = peer.create_server(port, 1)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_host = true
    player_id = 1
    multiplayer.peer_connected.connect(_on_peer_connected)
    return OK

func join_game(ip: String, port: int = 7777):
    var err = peer.create_client(ip, port)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_host = false
    player_id = 2
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    return OK

func _on_peer_connected(id: int):
    player_id = id
    player_connected.emit()

func _on_connected_to_server():
    player_id = 1
    player_connected.emit()

func _on_peer_disconnected(id: int):
    player_disconnected.emit()

@rpc("authority", "call_remote", "reliable")
func sync_game_start(white_pieces: Array, black_pieces: Array):
    game_started.emit()

@rpc("any_peer", "call_remote", "reliable")
func send_move(from: Vector2i, to: Vector2i):
    move_received.emit(from, to)

func start_game(white_pieces: Array, black_pieces: Array):
    if is_host:
        sync_game_start.rpc(white_pieces, black_pieces)

func submit_move(from: Vector2i, to: Vector2i):
    if is_host:
        send_move.rpc(from, to)
    else:
        send_move.rpc_id(1, from, to)
```

- [ ] **Step 2: Register as autoload in project.godot**

Add to `project.godot` under `[autoload]`:

```
NetworkManager="*res://scripts/network_manager.gd"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/network_manager.gd project.godot
git commit -m "feat: add NetworkManager autoload for ENet peer-to-peer"
```

---

### Task 2: Create lobby scene

**Covers:** Connection UI

**Files:**
- Create: `scripts/lobby.gd`
- Create: `scenes/lobby.tscn`

**Interfaces:**
- Consumes: NetworkManager host_game, join_game
- Produces: lobby UI with host/join buttons, IP/port inputs

- [ ] **Step 1: Create lobby.gd**

Create `scripts/lobby.gd`:

```gdscript
extends Control

@onready var host_port = $VBoxContainer/HostSection/PortInput
@onready var host_button = $VBoxContainer/HostSection/HostButton
@onready var join_ip = $VBoxContainer/JoinSection/IPInput
@onready var join_port = $VBoxContainer/JoinSection/PortInput
@onready var join_button = $VBoxContainer/JoinSection/JoinButton
@onready var status_label = $StatusLabel
@onready var back_button = $BackButton

func _ready():
    host_button.pressed.connect(_on_host_pressed)
    join_button.pressed.connect(_on_join_pressed)
    back_button.pressed.connect(_on_back_pressed)
    NetworkManager.player_connected.connect(_on_player_connected)
    NetworkManager.game_started.connect(_on_game_started)

func _on_host_pressed():
    var port = int(host_port.text) if host_port.text != "" else 7777
    var err = NetworkManager.host_game(port)
    if err == OK:
        status_label.text = "Hosting on port " + str(port) + "\nWaiting for opponent..."
        host_button.disabled = true
        join_button.disabled = true
    else:
        status_label.text = "Failed to host: " + str(err)

func _on_join_pressed():
    var ip = join_ip.text if join_ip.text != "" else "127.0.0.1"
    var port = int(join_port.text) if join_port.text != "" else 7777
    var err = NetworkManager.join_game(ip, port)
    if err == OK:
        status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
        host_button.disabled = true
        join_button.disabled = true
    else:
        status_label.text = "Failed to connect: " + str(err)

func _on_player_connected():
    if NetworkManager.is_host:
        status_label.text = "Opponent connected!\nStarting game..."
        var white_pieces = PozycjaOsobista.ustawienia_bialych.duplicate()
        var black_pieces = PozycjaOsobista.ustawienia_czarnych.duplicate()
        NetworkManager.start_game(white_pieces, black_pieces)
        get_tree().change_scene_to_file("res://scenes/main.tscn")
    else:
        status_label.text = "Connected! Waiting for host to start..."

func _on_game_started():
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed():
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer = null
    get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
```

- [ ] **Step 2: Create lobby.tscn scene**

Create `scenes/lobby.tscn`:

```
[gd_scene load_steps=2 format=4 uid="uid://lobby0001"]

[ext_resource type="Script" path="res://scripts/lobby.gd" id="1_lobby"]

[node name="Lobby" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_lobby")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -100.0
offset_right = 150.0
offset_bottom = 100.0
grow_horizontal = 2
grow_vertical = 2

[node name="HostSection" type="VBoxContainer" parent="VBoxContainer"]
layout_mode = 2

[node name="HostLabel" type="Label" parent="VBoxContainer/HostSection"]
layout_mode = 2
text = "Host Game"
horizontal_alignment = 1

[node name="PortInput" type="LineEdit" parent="VBoxContainer/HostSection"]
layout_mode = 2
placeholder_text = "Port (default: 7777)"
text = "7777"

[node name="HostButton" type="Button" parent="VBoxContainer/HostSection"]
layout_mode = 2
text = "Host"

[node name="JoinSection" type="VBoxContainer" parent="VBoxContainer"]
layout_mode = 2

[node name="JoinLabel" type="Label" parent="VBoxContainer/JoinSection"]
layout_mode = 2
text = "Join Game"
horizontal_alignment = 1

[node name="IPInput" type="LineEdit" parent="VBoxContainer/JoinSection"]
layout_mode = 2
placeholder_text = "IP Address (default: 127.0.0.1)"

[node name="PortInput" type="LineEdit" parent="VBoxContainer/JoinSection"]
layout_mode = 2
placeholder_text = "Port (default: 7777)"
text = "7777"

[node name="JoinButton" type="Button" parent="VBoxContainer/JoinSection"]
layout_mode = 2
text = "Join"

[node name="StatusLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -60.0
grow_horizontal = 2
grow_vertical = 0
horizontal_alignment = 1
text = ""

[node name="BackButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -30.0
grow_horizontal = 2
grow_vertical = 0
text = "Back"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/lobby.gd scenes/lobby.tscn
git commit -m "feat: add lobby scene for hosting/joining games"
```

---

### Task 3: Add online button to main menu

**Covers:** Menu integration

**Files:**
- Modify: `scripts/menu_glowne.gd`
- Modify: `scenes/menu glowne.tscn`

**Interfaces:**
- Consumes: lobby.tscn
- Produces: "Online" button in main menu

- [ ] **Step 1: Update menu_glowne.gd**

Add function to `scripts/menu_glowne.gd`:

```gdscript
func _on_online_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/lobby.tscn")
```

- [ ] **Step 2: Add Online button to menu scene**

Add to `scenes/menu glowne.tscn`:

```
[node name="Online" type="Button" parent="."]
offset_left = 150.0
offset_top = 300.0
offset_right = 350.0
offset_bottom = 340.0
text = "Online"

[connection signal="pressed" from="Online" to="." method="_on_online_pressed"]
```

- [ ] **Step 3: Commit**

```bash
git add scripts/menu_glowne.gd "scenes/menu glowne.tscn"
git commit -m "feat: add Online button to main menu"
```

---

### Task 4: Modify main.gd for network sync

**Covers:** Game synchronization

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: NetworkManager signals, PozycjaOsobista
- Produces: synchronized game state between host and client

- [ ] **Step 1: Add network variables and setup**

Add after line 28 (`var kolor_posuniecia = null`):

```gdscript
var my_color = ""
```

- [ ] **Step 2: Update _ready to handle network setup**

Update `_ready` function:

```gdscript
func _ready() -> void:
    add_to_group("game_main")
    generacja_pol(6)
    if NetworkManager.player_id > 0:
        my_color = "b" if NetworkManager.is_host else "c"
        NetworkManager.move_received.connect(_on_network_move)
        NetworkManager.player_disconnected.connect(_on_player_disconnected)
        ustawienie_z_pozycji()
        if NetworkManager.is_host:
            kolor_posuniecia = "b"
        else:
            kolor_posuniecia = "b"
            $HUD/ZmianaButton.visible = false
    else:
        losowanie()
        ustawienie_z_pozycji()
    $dzwiek/muzyka w tle".play()
```

- [ ] **Step 3: Add network move handler**

Add new function:

```gdscript
func _on_network_move(from: Vector2i, to: Vector2i):
    var figura = null
    for f in figury:
        if plansza.local_to_map(f.global_position) == from and f.kolor == kolor_posuniecia:
            figura = f
            break
    if figura:
        ruch(figura, to)
```

- [ ] **Step 4: Add disconnect handler**

Add new function:

```gdscript
func _on_player_disconnected():
    get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
```

- [ ] **Step 5: Modify ruch to send moves over network**

Update `ruch` function to send moves:

```gdscript
func ruch(figura, pole: Vector2i):
    if NetworkManager.player_id > 0 and figura.kolor != my_color:
        return
    if NetworkManager.player_id > 0:
        NetworkManager.submit_move(plansza.local_to_map(figura.global_position), pole)
    koniec_tury()
    if stoi_figura(pole) != null:
        zbicie(stoi_figura(pole))
    figura.global_position = plansza.map_to_local(pole)
    if moze_promowac(figura):
        figura.promocja("H")
    $dzwiek/ruch.play()
    if czy_szach("b") or czy_szach("c"):
        $dzwiek/szach.play()
        if legalne_posuniecia(get_king(kolor_posuniecia)) == []:
            koniec_gry(kolor_posuniecia)
    elif czy_pat(kolor_posuniecia):
        koniec_gry()
```

- [ ] **Step 6: Modify stan_idle to only allow moves on your turn**

Update `stan_idle` function:

```gdscript
func stan_idle(wskazane_pole):
    if NetworkManager.player_id > 0 and kolor_posuniecia != my_color:
        return
    if Input.is_action_just_pressed("space"):
        var tiles_left = bialy_tiles if kolor_posuniecia == "b" else czarny_tiles
        if tiles_left > 0:
            w_trakcie_rzucania = true
            stan = stany.PLACEMENT
            return
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if najechana_figura() and najechana_figura().kolor == kolor_posuniecia:
            chwyc(najechana_figura())
            stan = stany.GRAB
```

- [ ] **Step 7: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: add network synchronization to main game logic"
```

---

### Task 5: Verify implementation

**Covers:** Testing

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: all previous tasks
- Produces: passing verification

- [ ] **Step 1: Run Godot headless to check for parse errors**

```bash
cd /Users/konrad/zryj-chess-main
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/network_manager.gd 2>&1 | head -20
```

Expected: No parse errors

- [ ] **Step 2: Verify all scenes load**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --check-only 2>&1
```

Expected: No errors

- [ ] **Step 3: Mark task T1 as done**

```bash
# Verification complete
```
