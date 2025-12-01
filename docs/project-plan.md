# 🚀 Godot Auto-Battler Prototype – Day 1 Plan

**Goal:** Get a playable prototype with placeholder squares that move, fight, and resolve a battle.

---

## Status

- [x] Create Godot 4.5 project
- [x] Add folder structure (scenes/, scripts/, assets/)
- [ ] Build scene structure
- [x] Implement Unit behavior
- [ ] Implement Game flow
- [ ] Playtest and iterate

---

## Summary

**Task 1:** Build `unit.tscn` — a colored square that can move, fight, and die.  
**Task 2:** Build `game.tscn` — the battlefield with UI buttons and unit containers.  
**Task 3:** ✅ Implement placement phase — click button to spawn player units. (Completed via `docs/plans/2025-12-01-placement-phase.md`)  
**Task 4:** ✅ Implement battle phase — units move toward each other, fight on contact. (Completed via `docs/plans/2025-12-01-battle-phase.md`)  
**Task 5:** Implement end phase — survivors damage fortress, restart button appears.

---

## Tooling

- Added `tools/godot-log-tail.ps1` for quickly tailing the Godot log: `pwsh -File .\tools\godot-log-tail.ps1 15`

---

## Scene Structure

### unit.tscn

```
Unit (Node2D)
└─ Sprite2D (colored square placeholder)
```

### game.tscn

```
Game (Node2D)
├─ Fortress (Sprite2D)       ← far left, visual target for enemies
├─ PlayerUnits (Node2D)      ← y_sort_enabled = true
├─ EnemyUnits (Node2D)       ← y_sort_enabled = true
└─ UI (CanvasLayer)
    ├─ SpawnButton (Button)   ← "Add Unit"
    ├─ StartButton (Button)   ← "Fight!"
    ├─ RestartButton (Button) ← hidden until battle ends
    └─ HpLabel (Label)        ← shows fortress HP
```

---

## Tasks

### Task 1: Unit Scene & Script

Create `unit.tscn` with `unit.gd` attached.

**Variables:**

```gdscript
var max_hp := 3
var current_hp := 3
var damage := 1
var speed := 100.0           # pixels per second
var attack_range := 50.0     # radius to detect enemies
var attack_cooldown := 1.0   # seconds between attacks

var is_enemy := false        # determines movement direction
var state := "idle"          # idle | moving | fighting
var target: Node2D = null
var time_since_attack := 0.0
```

**Behavior:**

- `idle`: Do nothing, wait for battle start
- `moving`: Walk toward enemy side (right if player, left if enemy)
  - Every frame, check for enemies within `attack_range`
  - If enemy found → set `target` to closest, switch to `fighting`
- `fighting`: Attack target every `attack_cooldown` seconds
  - Deal `damage` to target
  - If target dies → clear target, switch to `moving`
- `die()`: When `current_hp <= 0`, call `queue_free()`

### Task 2: Game Scene Layout

Create `game.tscn` with `game.gd` attached.

- Position `Fortress` at far left (e.g., x=50)
- Position `PlayerUnits` spawn area on left side
- Position `EnemyUnits` spawn area on right side
- Enable `y_sort_enabled` on both unit containers
- Set up UI buttons with placeholder text

### ✅ Task 3: Placement Phase

**Status:** Completed via `docs/plans/2025-12-01-placement-phase.md`

In `game.gd`:

**Variables:**

```gdscript
var player_hp := 10
var phase := "placement"  # placement | battle | end
var player_slots := [Vector2(150, 200), Vector2(150, 300), Vector2(150, 400)]
var current_slot := 0

@export var unit_scene: PackedScene
```

**SpawnButton logic:**

- Instantiate `unit_scene`
- Set position to `player_slots[current_slot]`
- Add as child of `PlayerUnits`
- Increment `current_slot`
- Disable button if all slots filled

**On `_ready()`:**

- Spawn 2-3 enemies on right side (hardcoded positions)
- Connect button signals

### ✅ Task 4: Battle Phase

**Status:** Completed via `docs/plans/2025-12-01-battle-phase.md`

**StartButton logic:**

- Set `phase = "battle"`
- Loop through all units in `PlayerUnits` and `EnemyUnits`
- Set each unit's `state = "moving"`
- Hide SpawnButton, disable StartButton

**In `_process()`:**

- If `phase == "battle"`:
  - Check if all enemies dead → player wins
  - Check if all player units dead → enemies win
  - If either → call `_end_battle()`

**Unit targeting (in unit.gd):**

- Unit finds enemies by getting nodes from the opposite container
- `get_tree().get_nodes_in_group("enemies")` or pass reference to enemy container
- Check distance to each, target closest within range

### Task 5: End Phase

**`_end_battle()` logic:**

- Count surviving enemies
- Subtract from `player_hp` (1 HP per survivor, or per enemy that reaches fortress)
- Update `HpLabel`
- Show `RestartButton`
- Set `phase = "end"`

**RestartButton logic:**

- Clear all children from `PlayerUnits` and `EnemyUnits`
- Reset `current_slot = 0`
- Re-spawn enemies
- Reset button states
- Set `phase = "placement"`

---

## Exit Criteria

- [ ] Can click button to spawn player units on left side
- [ ] Enemies appear on right side
- [ ] Click Fight → units walk toward each other
- [ ] Units stop and fight when in range
- [ ] Units die when HP reaches 0
- [ ] Battle ends when one side is eliminated
- [ ] Surviving enemies reduce fortress HP
- [ ] Can restart and play again

---

## Future Phases (Not Today)

### Phase 2: Multi-Round Progression

- Track round number
- Increase enemy count/difficulty each round
- "Next Round" flow instead of full restart

### Phase 3: Unit Variety

- Multiple unit types (Tank, DPS, Ranged)
- Different stats per type
- Multiple spawn buttons

### Phase 4: Economy

- Gold system
- Unit costs
- Earn gold per round

### Phase 5: Polish

- Sprite art
- Hit effects
- Death animations
- Sound effects
- UI polish
