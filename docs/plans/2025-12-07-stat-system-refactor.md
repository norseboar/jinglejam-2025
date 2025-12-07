# Stat System Refactor Implementation Plan

**Goal:** Refactor stat system to use display values with conversions, replace attack cooldown with attack speed, and calculate gold reward dynamically.

---

## Status

- [ ] Task 1: Update Unit Stats - Add attack_speed, update speed/range conversions
- [ ] Task 2: Update Attack Cooldown Logic - Use effective cooldown calculation
- [ ] Task 3: Update Gold Reward - Remove export, calculate dynamically
- [ ] Task 4: Update Upgrade System - Replace ATTACK_COOLDOWN with ATTACK_SPEED

---

## Summary

**Task 1: Update Unit Stats** — Add attack_speed stat, update speed and attack_range to use display values with conversions when used.

**Task 2: Update Attack Cooldown Logic** — Calculate effective cooldown as `attack_cooldown - (attack_speed * 0.5)` and use it throughout.

**Task 3: Update Gold Reward** — Remove `@export var gold_reward`, calculate dynamically in `die()` as `(base_recruit_cost + upgrade_cost * total_upgrades) / 2`.

**Task 4: Update Upgrade System** — Replace ATTACK_COOLDOWN stat type with ATTACK_SPEED in upgrade resource and application logic.

---

## Tasks

### Task 1: Update Unit Stats

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add `attack_speed` stat after `attack_cooldown` (around line 14):

```gdscript
@export var attack_cooldown := 0.0   # seconds to wait in idle after attack animation completes (0 = no cooldown)
@export var attack_speed := 0  # Attack speed stat (reduces cooldown by 0.5 seconds per point)
```

- [ ] **Step 2:** Update speed usage in `_do_movement()` to multiply by 10 (lines 129 and 141):

Replace:
```gdscript
position += direction_to_target * speed * delta
```

With:
```gdscript
position += direction_to_target * speed * 10.0 * delta
```

And replace:
```gdscript
position.x += direction * speed * delta
```

With:
```gdscript
position.x += direction * speed * 10.0 * delta
```

- [ ] **Step 3:** Update attack_range usage in `_check_for_targets()` to multiply by 10 and add 20 (line 223):

Replace:
```gdscript
if distance_to_target <= attack_range:
```

With:
```gdscript
if distance_to_target <= (attack_range * 10.0 + 20.0):
```

- [ ] **Step 4:** Update attack_range usage in `_do_fighting()` to multiply by 10 and add 20 (line 251):

Replace:
```gdscript
if distance > attack_range * 1.2:
```

With:
```gdscript
if distance > (attack_range * 10.0 + 20.0) * 1.2:
```

**Verify:** File has no syntax errors. Speed and attack_range now use display values with conversions.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Update Attack Cooldown Logic

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add a helper function to calculate effective cooldown (add after `apply_upgrades()` function, around line 475):

```gdscript
func _get_effective_cooldown() -> float:
	"""Calculate effective cooldown: base cooldown minus attack speed bonus."""
	var effective := attack_cooldown - (attack_speed * 0.5)
	return max(0.0, effective)  # Ensure cooldown never goes below 0
```

- [ ] **Step 2:** Update `_check_for_targets()` to use effective cooldown (lines 228-232):

Replace:
```gdscript
if self is Archer or self is ArtilleryUnit:
	# Random delay between 0 and attack_cooldown for first attack
	time_since_attack = randf() * attack_cooldown
else:
	# Melee units (Swordsman) attack immediately
	time_since_attack = attack_cooldown  # Set to cooldown value so attack happens immediately
```

With:
```gdscript
var effective_cooldown := _get_effective_cooldown()
if self is Archer or self is ArtilleryUnit:
	# Random delay between 0 and effective_cooldown for first attack
	time_since_attack = randf() * effective_cooldown
else:
	# Melee units (Swordsman) attack immediately
	time_since_attack = effective_cooldown  # Set to cooldown value so attack happens immediately
```

- [ ] **Step 3:** Update `_do_fighting()` to use effective cooldown (lines 259-263):

Replace:
```gdscript
if attack_cooldown <= 0.0 or time_since_attack >= attack_cooldown:
```

With:
```gdscript
var effective_cooldown := _get_effective_cooldown()
if effective_cooldown <= 0.0 or time_since_attack >= effective_cooldown:
```

And replace:
```gdscript
else:
	# Count cooldown timer during idle (after attack animation completes)
	time_since_attack += delta
```

With:
```gdscript
else:
	# Count cooldown timer during idle (after attack animation completes)
	time_since_attack += delta
```

- [ ] **Step 4:** Update `_on_attack_animation_finished()` to use effective cooldown (lines 313-314):

Replace:
```gdscript
if attack_cooldown > 0.0:
	time_since_attack = 0.0
```

With:
```gdscript
var effective_cooldown := _get_effective_cooldown()
if effective_cooldown > 0.0:
	time_since_attack = 0.0
```

**Verify:** File has no syntax errors. Attack cooldown now uses effective cooldown calculation.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update Gold Reward

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Remove the `@export var gold_reward` line (line 28):

Remove:
```gdscript
@export var gold_reward := 5  # Gold given when this unit is killed
```

- [ ] **Step 2:** Add a helper function to calculate gold reward (add after `_get_effective_cooldown()`, around line 480):

```gdscript
func _calculate_gold_reward() -> int:
	"""Calculate gold reward based on unit cost and upgrades."""
	var total_upgrades := 0
	for count in upgrades.values():
		total_upgrades += count
	var total_cost := base_recruit_cost + (upgrade_cost * total_upgrades)
	return int(total_cost / 2.0)
```

- [ ] **Step 3:** Update `die()` to calculate gold reward dynamically (line 429):

Replace:
```gdscript
enemy_unit_died.emit(gold_reward, global_position)
```

With:
```gdscript
var gold_reward := _calculate_gold_reward()
enemy_unit_died.emit(gold_reward, global_position)
```

**Verify:** File has no syntax errors. Gold reward is now calculated dynamically.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Update Upgrade System

**Files:** `scripts/upgrade.gd`, `scripts/unit.gd`

- [ ] **Step 1:** Update the StatType enum in `scripts/upgrade.gd` to replace ATTACK_COOLDOWN with ATTACK_SPEED:

Replace:
```gdscript
enum StatType {
	MAX_HP,
	DAMAGE,
	SPEED,
	ATTACK_RANGE,
	ATTACK_COOLDOWN,
	ARMOR
}
```

With:
```gdscript
enum StatType {
	MAX_HP,
	DAMAGE,
	SPEED,
	ATTACK_RANGE,
	ATTACK_SPEED,
	ARMOR
}
```

- [ ] **Step 2:** Update `apply_upgrades()` in `scripts/unit.gd` to handle ATTACK_SPEED instead of ATTACK_COOLDOWN (around line 468):

Replace:
```gdscript
UnitUpgrade.StatType.ATTACK_COOLDOWN:
	attack_cooldown -= total_amount  # Note: negative to reduce cooldown
```

With:
```gdscript
UnitUpgrade.StatType.ATTACK_SPEED:
	attack_speed += total_amount
```

**Verify:** File has no syntax errors. Upgrade system now uses ATTACK_SPEED instead of ATTACK_COOLDOWN.

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Speed is stored as display value and multiplied by 10 when used for movement
- [ ] Attack range is stored as display value and converted (range * 10 + 20) when used for distance checks
- [ ] Attack cooldown uses effective cooldown calculation: `attack_cooldown - (attack_speed * 0.5)`
- [ ] Gold reward is calculated dynamically as `(base_recruit_cost + upgrade_cost * total_upgrades) / 2`
- [ ] Upgrade system uses ATTACK_SPEED instead of ATTACK_COOLDOWN
- [ ] No errors in console when units move, attack, or die

