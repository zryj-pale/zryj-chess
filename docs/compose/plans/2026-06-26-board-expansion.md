# Board Expansion Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable board expansion where each player can place 2 tiles per game during their turn, with a HUD showing remaining tiles.

**Architecture:** Add tile tracking variables and a PLACEMENT state to the existing state machine in `main.gd`. Create a simple HUD scene with labels for tile counts.

**Tech Stack:** Godot 4.7, GDScript

---

### Task 1: Add tile tracking state to main.gd

**Covers:** Tile resource tracking

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: existing `kolor_posuniecia` for current player
- Produces: `bialy_tiles`, `czarny_tiles` variables; `w_trakcie_rzucania` state flag

- [ ] **Step 1: Add tile count variables**

Add after line 24 (`var wybrana = null`):

```gdscript
var bialy_tiles = 2
var czarny_tiles = 2
var w_trakcie_rzucania = false
```

- [ ] **Step 2: Add PLACEMENT state to enum**

Change the enum on line 7-11 to:

```gdscript
enum stany{
    IDLE,
    GRAB,
    SELECT,
    PLACEMENT
}
```

- [ ] **Step 3: Update _process to handle PLACEMENT state**

In `_process` (line 52-60), add PLACEMENT case:

```gdscript
func _process(_delta: float) -> void:
    var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
    match stan:
        stany.IDLE:
            stan_idle(wskazane_pole)
        stany.GRAB:
            stan_grab(wskazane_pole)
        stany.SELECT:
            stan_select(wskazane_pole)
        stany.PLACEMENT:
            stan_placement(wskazane_pole)
```

- [ ] **Step 4: Add stan_placement function**

Add after `stan_select` function:

```gdscript
func stan_placement(wskazane_pole):
    if Input.is_action_just_pressed("space"):
        w_trakcie_rzucania = false
        stan = stany.IDLE
        return
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if pole_na_planszy(wskazane_pole) and stoi_figura(wskazane_pole) == null:
            dodaj_pole(wskazane_pole)
            if kolor_posuniecia == "b":
                bialy_tiles -= 1
            else:
                czarny_tiles -= 1
            w_trakcie_rzucania = false
            stan = stany.IDLE
            $dzwiek/ruch.play()
```

- [ ] **Step 5: Update stan_idle to allow entering placement mode**

Replace `stan_idle` function (lines 62-66):

```gdscript
func stan_idle(wskazane_pole):
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

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: add tile tracking and PLACEMENT state"
```

---

### Task 2: Update koniec_tury to reset placement flag

**Covers:** Turn flow

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `w_trakcie_rzucania` from Task 1
- Produces: cleared flag at turn end

- [ ] **Step 1: Update koniec_tury function**

Replace `koniec_tury` function (lines 166-170):

```gdscript
func koniec_tury():
    w_trakcie_rzucania = false
    if kolor_posuniecia == "b":
        kolor_posuniecia = "c"
    else:
        kolor_posuniecia = "b"
```

- [ ] **Step 2: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: reset placement flag on turn change"
```

---

### Task 3: Create HUD scene

**Covers:** HUD display

**Files:**
- Create: `scenes/hud.tscn`
- Create: `scripts/hud.gd`

**Interfaces:**
- Consumes: `bialy_tiles`, `czarny_tiles`, `kolor_posuniecia` from main.gd
- Produces: HUD node to be added to main scene

- [ ] **Step 1: Create hud.gd script**

Create `scripts/hud.gd`:

```gdscript
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
```

- [ ] **Step 2: Create hud.tscn scene**

Create `scenes/hud.tscn` with:
- Root: CanvasLayer (script: hud.gd)
- BialyLabel: Label at position (10, 10), text "Biale: 2"
- CzarnyLabel: Label at position (10, 30), text "Czarne: 2"

- [ ] **Step 3: Commit**

```bash
git add scenes/hud.tscn scripts/hud.gd
git commit -m "feat: add HUD scene for tile counts"
```

---

### Task 4: Integrate HUD into main scene

**Covers:** HUD integration

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: hud.tscn from Task 3
- Produces: HUD visible in game

- [ ] **Step 1: Add HUD to main.tscn**

Add HUD instance to `scenes/main.tscn` as a child of root node.

- [ ] **Step 2: Add game_main group to root node**

In `scripts/main.gd` `_ready` function, add:

```gdscript
func _ready() -> void:
    add_to_group("game_main")
    generacja_pol(6)
    domyslne_ustawienie()
    losowanie()
    ustawienie_z_pozycji()
```

- [ ] **Step 3: Commit**

```bash
git add scenes/main.tscn scripts/main.gd
git commit -m "feat: integrate HUD into main scene"
```

---

### Task 5: Update input handling for placement mode

**Covers:** Input validation

**Files:**
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: PLACEMENT state from Task 1
- Produces: disabled _input during placement

- [ ] **Step 1: Update _input to skip during placement**

Replace `_input` function (lines 107-110):

```gdscript
func _input(_event: InputEvent) -> void:
    if w_trakcie_rzucania:
        return
    if dodawanie_pol == true:
        if Input.is_action_just_pressed("space"):
            dodaj_pole(plansza.local_to_map(get_global_mouse_position()))
```

- [ ] **Step 2: Enable dodawanie_pol by default**

Change line 4 from:

```gdscript
@export var dodawanie_pol = false
```

to:

```gdscript
@export var dodawanie_pol = true
```

- [ ] **Step 3: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: enable board expansion and handle input during placement"
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
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/main.gd 2>&1 | head -20
```

Expected: No parse errors

- [ ] **Step 2: Verify scene loads**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --check-only 2>&1
```

Expected: No errors

- [ ] **Step 3: Mark task T1 as done**

```bash
# Verification complete
```
