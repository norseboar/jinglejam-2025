extends Unit
class_name Healer

## Healer - unit that heals wounded allies within range.

@export var heal_vfx_scene: PackedScene = preload("res://units/demons/healing_vfx.tscn")


func _ready() -> void:
	# Set default stats for healer (can be overridden in inspector)
	if max_hp == 3:
		max_hp = 3  # Moderate HP
	if attack_range == 50.0:
		attack_range = 150.0  # Ranged healing
	if attack_cooldown == 1.0:
		attack_cooldown = 2.0  # Slower heal cadence
	if speed == 100.0:
		speed = 90.0  # Slightly slower movement
	# Set default heal amount if not set in scene
	if heal_amount == 0:
		heal_amount = 2

	super._ready()


func _process(delta: float) -> void:
	# Override to scan for targets even when idle
	if state == "idle":
		_check_for_targets()
		# If we found a target, switch to moving to approach them
		if target != null and is_instance_valid(target):
			set_state("moving")
	else:
		# For other states, use parent behavior
		super._process(delta)


func _do_movement(delta: float) -> void:

	# Check for wounded allies
	_check_for_targets()

	# If we have a target, move towards it
	if target != null and is_instance_valid(target):
		var target_pos := target.position
		var direction_to_target := (target_pos - position).normalized()

		# Move towards target
		position += direction_to_target * speed * delta

		# Flip sprite to face movement direction
		animated_sprite.flip_h = direction_to_target.x < 0
	else:
		# No target - healers don't move forward, they stay idle
		# (state will be set to idle by _check_for_targets if we're moving)
		pass


## Override targeting to find wounded allies instead of enemies
func _check_for_targets() -> void:
	if friendly_container == null:
		return

	var closest_ally: Unit = null
	var closest_distance := INF

	# Priority-based targeting: find highest priority wounded ally, then closest
	var highest_priority := -INF
	var high_priority_allies: Array[Unit] = []

	# First pass: find highest priority among wounded allies
	for ally in friendly_container.get_children():
		if not is_instance_valid(ally):
			continue
		if not ally is Unit:
			continue

		var ally_unit := ally as Unit
		if ally_unit == self or ally_unit.current_hp >= ally_unit.max_hp or ally_unit.state == "dying":
			continue  # Skip self, healthy, or dying allies

		var distance := position.distance_to(ally.position)
		if distance >= detection_range:
			continue

		if ally_unit.priority > highest_priority:
			highest_priority = ally_unit.priority

	# Second pass: collect all wounded allies with highest priority
	for ally in friendly_container.get_children():
		if not is_instance_valid(ally):
			continue
		if not ally is Unit:
			continue

		var ally_unit := ally as Unit
		if ally_unit == self or ally_unit.current_hp >= ally_unit.max_hp or ally_unit.state == "dying":
			continue

		var distance := position.distance_to(ally.position)
		if distance >= detection_range:
			continue

		if ally_unit.priority == highest_priority:
			high_priority_allies.append(ally_unit)

	# Third pass: find closest among high priority wounded allies
	for ally_unit in high_priority_allies:
		var distance := position.distance_to(ally_unit.position)
		if distance < closest_distance:
			closest_ally = ally_unit
			closest_distance = distance

	if closest_ally != null:
		target = closest_ally
		var distance_to_target := position.distance_to(closest_ally.position)

		# If we're in heal range, start fighting (healing)
		if distance_to_target <= attack_range:
			set_state("fighting")
		# Otherwise, we'll keep moving towards them (state stays "moving")
	else:
		# No wounded allies found - healers should idle instead of moving forward
		target = null
		if state == "moving":
			set_state("idle")


## Override to play heal sound on attack frame
func _trigger_attack_damage() -> void:
	"""Play heal sound on the attack frame."""
	has_triggered_frame_damage = true
	_play_fire_sound()  # Reuse fire sound for heal sound
	_execute_attack()


## Override to perform healing instead of damage
func _execute_attack() -> void:
	_perform_heal()


## Helper method to perform the actual healing
func _perform_heal() -> void:
	if target == null or not is_instance_valid(target) or not target is Unit:
		return

	var target_unit := target as Unit

	# Validate target is still alive, friendly, and wounded
	if target_unit.current_hp <= 0 or target_unit.state == "dying":
		return
	if target_unit.current_hp >= target_unit.max_hp:
		return

	# Heal the target
	target_unit.receive_heal(heal_amount)

	# Spawn healing VFX at target position
	if heal_vfx_scene != null:
		var vfx: Node2D = heal_vfx_scene.instantiate() as Node2D
		if vfx != null:
			# Add to target's parent so it auto-cleans like other VFX
			target_unit.get_parent().add_child(vfx)
			vfx.global_position = target_unit.global_position
