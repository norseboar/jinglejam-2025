# Healer Unit Implementation Plan

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

**Goal:** Add a healer unit that moves within attack range to heal wounded allies on its attack frame with sound/VFX, using attack cooldown as heal cadence.

---

## Status

- [ ] Task 1: Enable heal targeting
- [ ] Task 2: Implement healer logic
- [ ] Task 3: Wire scenes & rosters

---

## Summary

**Task 1: Enable heal targeting** — Add friendly-container plumbing and a heal helper on Unit/Game.

**Task 2: Implement healer logic** — Create healer script with ally targeting, heal timing, SFX/VFX.

**Task 3: Wire scenes & rosters** — Godot editor: create healer scene, set stats, add to rosters, assign VFX/SFX.

---

## Tasks

### Task 1: Enable heal targeting

**Files:** `scripts/unit.gd`, `scripts/game.gd`

- [ ] **Step 1:** In `scripts/unit.gd`, add a `friendly_container: Node2D` property (same-team container) and a `receive_heal(amount: int)` helper that clamps `current_hp` to `max_hp`, skips if dying, and avoids side effects beyond HP/tint reset.
- [ ] **Step 2:** In `scripts/unit.gd`, ensure `receive_heal` no-ops when already at full health and keeps behavior safe for both teams.
- [ ] **Step 3:** In `scripts/game.gd`, set `friendly_container` when spawning units:
  - Player units: set in `place_unit_from_army` to `player_units`.
  - Enemy units: set in `_spawn_enemies_from_level` and `_spawn_enemies_from_generated_army` to `enemy_units`.
- [ ] **Step 4:** Keep existing targeting for non-healers unchanged; only new code should be used by healer subclasses.

**Verify:** Run the game, place any unit, and confirm no errors on spawn; friendly_container assignments are present (via print or debugger) and existing combat still works.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Implement healer logic

**Files:** `scripts/healer.gd`, `scripts/unit.gd` (override calls), optional `units/demons/healing_vfx.tscn` reference

- [ ] **Step 1:** Create `scripts/healer.gd` extending `Unit` with exports: `heal_amount` (int), `heal_vfx_scene: PackedScene` (default to `res://units/demons/healing_vfx.tscn`), and reuse `fire_sounds` for heal SFX (or a dedicated heal sound array if added).
- [ ] **Step 2:** In `_ready()`, set healer defaults if untouched (e.g., moderate HP, ranged `attack_range`, slower `attack_cooldown`, tuned speed) then call `super._ready()`.
- [ ] **Step 3:** Override `_check_for_targets()` to scan `friendly_container` for Units with `current_hp < max_hp`, skip self/dying, respect `detection_range`, pick highest `priority` then closest; if within `attack_range`, set state to `"fighting"`; otherwise move toward target; if none, idle/move as base.
- [ ] **Step 4:** Override `_trigger_attack_damage()` to set `has_triggered_frame_damage`, log, play heal sound (`_play_fire_sound()` or new heal sound), and call `_execute_attack()`; only fire on `attack_damage_frame`.
- [ ] **Step 5:** Implement `_execute_attack()` to call a helper (e.g., `_perform_heal()`) that:
  - Validates the target is alive, friendly, and wounded.
  - Calls `target.receive_heal(heal_amount)`.
  - Spawns `heal_vfx_scene` at the target’s `global_position` (add to target’s parent or shared container) so it auto-cleans like explosion VFX.
  - Leaves base attack animation/cooldown flow unchanged (no projectile).
- [ ] **Step 6:** Handle edge cases: if target is dead/full at frame time, skip heal but let cooldown proceed; ensure nothing damages enemies.

**Verify:** Spawn a healer with a wounded ally; observe move-to-range, attack animation triggers heal + sound/VFX on attack frame, ally HP rises, cooldown respected, no projectile spawned.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Wire scenes & rosters (Godot Editor)

**Files:** `units/humans/healer.tscn`, `units/rosters/starting_rosters/humans.tres`, `units/rosters/full_rosters/humans_full.tres` (and other rosters if desired)

- [ ] **Step 1:** **Godot Editor:** Duplicate a ranged unit scene (e.g., `units/unit.tscn` or a human ranged unit) to `units/humans/healer.tscn`; attach `scripts/healer.gd`.
- [ ] **Step 2:** **Godot Editor:** Set inspector values: `display_name`, `description`, `attack_range` (heal range), `attack_cooldown` (heal cadence), `heal_amount`, `priority`, `base_recruit_cost`, `upgrade_cost`, `gold_reward`, `attack_damage_frame`.
- [ ] **Step 3:** **Godot Editor:** Configure art/animation: set `AnimatedSprite2D` frames for idle/walk/attack; ensure attack animation has the frame marker matching `attack_damage_frame`.
- [ ] **Step 4:** **Godot Editor:** Assign audio/VFX: add a heal sound to `fire_sounds` (or dedicated heal sound export) and set `heal_vfx_scene` to `res://units/demons/healing_vfx.tscn` (or another heal effect). Leave impact sounds empty.
- [ ] **Step 5:** **Godot Editor:** Add healer to rosters: append the healer scene to `units/rosters/starting_rosters/humans.tres` and `units/rosters/full_rosters/humans_full.tres` (and any other roster that should include healers).
- [ ] **Step 6:** **Godot Editor:** Confirm tray/draft preview shows the healer (idle frame texture) and adjust spriteframes if needed.

**Verify:** In draft/prep, healer appears in roster/tray; during battle healer moves to allies and heals on the correct attack frame with sound/VFX; no console errors.

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Healer heals allies within attack range on the configured attack frame, with sound and heal VFX appearing and cleaning up after the animation.
- [ ] Heal amount and cooldown are configurable and respected; healer never spawns projectiles or damages enemies.
- [ ] Rosters/draft/auto-deploy include the healer and spawning works for player/enemy sides without errors.
- [ ] No regressions to existing unit combat behavior.

