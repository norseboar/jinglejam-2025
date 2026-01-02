extends Unit
class_name Healer

## Healer - unit that heals wounded allies within range.

@export var heal_vfx_scene: PackedScene = preload("res://units/demons/healing_vfx.tscn")


func _ready() -> void:
	# Use values from inspector - don't override them
	super._ready()


func set_state(new_state: String) -> void:
	super.set_state(new_state)


func _safe_play_animation(anim_name: String) -> void:
	super._safe_play_animation(anim_name)


func _process(delta: float) -> void:
	# Always call parent first for time tracking and base behavior
	super._process(delta)
	
	# Override to scan for targets even when idle, but only during combat
	if state == "idle":
		if _is_combat_active():
			_check_for_targets()
			# If we found a target, switch to moving to approach them
			if target != null and is_instance_valid(target):
				set_state("moving")


func _do_movement(delta: float) -> void:
	# If unit has fly_height set and hasn't reached it yet, fly to that height first
	if fly_height >= 0 and not has_reached_fly_height:
		var viewport_rect := get_viewport_rect()
		var target_y := viewport_rect.position.y + fly_height
		var current_y := position.y

		# Check if we've reached the target height
		if abs(current_y - target_y) < 5.0:
			position.y = target_y
			has_reached_fly_height = true
		else:
			# Fly towards target height
			var direction_y := -1.0 if current_y > target_y else 1.0
			position.y += direction_y * speed * 10.0 * delta

			# Don't overshoot
			if direction_y < 0 and position.y < target_y:
				position.y = target_y
				has_reached_fly_height = true
			elif direction_y > 0 and position.y > target_y:
				position.y = target_y
				has_reached_fly_height = true

		# While flying, don't do normal pathing yet
		return

	# Get navigation position for distance calculations
	var nav_pos := _get_nav_position()

	# Check if current target is still valid
	if target != null and is_instance_valid(target):
		var target_unit := target as Unit
		var target_nav_pos := target_unit._get_nav_position()
		var distance := nav_pos.distance_to(target_nav_pos)
		
		# Check if target went out of range or died
		if target_unit.state == "dying" or target_unit.current_hp <= 0:
			target = null
		elif distance > detection_range:
			target = null

	# Only check for new targets if we don't have a valid one
	# This prevents constant retargeting and state thrashing
	if target == null:
		_check_for_targets()

	# If we have a target, move towards it using pathfinding
	if target != null and is_instance_valid(target):
		var target_unit := target as Unit
		var target_nav_pos := target_unit._get_nav_position()
		var distance := nav_pos.distance_to(target_nav_pos)
		var effective_range := attack_range * 10.0 + 20.0

		# Check if we're now in range to attack
		if distance <= effective_range:
			set_state("fighting")
			return  # Don't move this frame, start attacking next frame

		# Use pathfinding for ground units, direct movement for flying units
		if fly_height >= 0:
			# Flying units: move directly toward target
			var direction_to_target := (target_nav_pos - nav_pos).normalized()
			position += direction_to_target * speed * 10.0 * delta
			animated_sprite.flip_h = direction_to_target.x < 0
		else:
			# Ground units: use navigation pathfinding
			if navigation_agent == null:
				push_error("[Navigation] Ground healer missing NavigationAgent2D node! Cannot pathfind.")
				return
			
			# Update navigation target
			if navigation_agent.target_position.distance_to(target_nav_pos) > 1.0:
				navigation_agent.target_position = target_nav_pos
			
			# Check distance to target
			if distance <= 5.0:
				# Close enough to target, don't move
				return
			
			# Try to get next position on path
			var next_path_position := navigation_agent.get_next_path_position()
			var distance_to_next := next_path_position.distance_to(nav_pos)
			
			# Follow navigation path if we have a valid one
			if distance_to_next > 1.0:
				# We have a valid path, follow it
				var direction: Vector2 = (next_path_position - nav_pos).normalized()
				var movement: Vector2 = direction * speed * 10.0 * delta
				var separation: Vector2 = _apply_separation_force() * delta
				position += movement + separation
				animated_sprite.flip_h = direction.x < 0
			else:
				# No valid path - log why
				if navigation_agent.is_navigation_finished():
					# Pathfinding finished but we're not at target - might be stuck
					push_warning("[Navigation] Healer '%s' navigation finished but not at target. Target: %s, Current: %s, Distance: %.1f" % [name, target_nav_pos, nav_pos, distance])
				else:
					# Pathfinding in progress but no next position - might be unreachable or nav map issue
					push_warning("[Navigation] Healer '%s' has no valid path. Target: %s, Current: %s, Nav map: %s" % [name, target_nav_pos, nav_pos, navigation_agent.get_navigation_map()])
	else:
		# No target - healers don't move forward, they stay idle
		# This is the key difference from base Unit behavior
		pass


## Override targeting to find wounded allies instead of enemies
func _check_for_targets() -> void:
	if friendly_container == null:
		return

	var nav_pos := _get_nav_position()

	# Categorize allies by priority
	var damaged_no_armor: Array[Unit] = []
	var damaged_with_armor: Array[Unit] = []
	var healthy_no_armor: Array[Unit] = []

	# Scan all friendly units and categorize them
	for ally in friendly_container.get_children():
		if not is_instance_valid(ally) or not ally is Unit:
			continue

		var ally_unit := ally as Unit
		if ally_unit == self or ally_unit.state == "dying" or ally_unit is Healer:
			continue  # Skip self, dying units, and other healers

		var ally_nav_pos := ally_unit._get_nav_position()
		var distance := nav_pos.distance_to(ally_nav_pos)
		if distance >= detection_range:
			continue
		
		# Check line of sight (healers can't heal through walls)
		if not has_clear_line_of_sight_to(ally_unit):
			continue

		var is_damaged := ally_unit.current_hp < ally_unit.max_hp
		var has_heal_armor := ally_unit.heal_armor > 0

		# Categorize based on damage and heal armor status
		if is_damaged and not has_heal_armor:
			damaged_no_armor.append(ally_unit)
		elif is_damaged and has_heal_armor:
			damaged_with_armor.append(ally_unit)
		elif not is_damaged and not has_heal_armor:
			healthy_no_armor.append(ally_unit)
		# Units with full HP and heal armor are ignored

	# Find closest unit from highest priority group
	var target_group: Array[Unit] = []
	if not damaged_no_armor.is_empty():
		target_group = damaged_no_armor
	elif not damaged_with_armor.is_empty():
		target_group = damaged_with_armor
	elif not healthy_no_armor.is_empty():
		target_group = healthy_no_armor

	# Find closest in target group
	var closest_ally: Unit = null
	var closest_distance := INF

	for ally_unit in target_group:
		var ally_nav_pos := ally_unit._get_nav_position()
		var distance := nav_pos.distance_to(ally_nav_pos)
		if distance < closest_distance:
			closest_ally = ally_unit
			closest_distance = distance

	# Set target (let _do_movement handle state changes based on range)
	if closest_ally != null:
		target = closest_ally
		# Don't change state here - let _process() or _do_movement handle it
	else:
		# No valid targets - stay near nearest ally but don't heal
		_find_nearest_ally_to_follow()


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

	# Validate target is still alive and friendly
	if target_unit.current_hp <= 0 or target_unit.state == "dying":
		return

	# Only heal if damaged OR (healthy but no heal armor)
	var is_damaged := target_unit.current_hp < target_unit.max_hp
	var has_heal_armor := target_unit.heal_armor > 0

	if not is_damaged and has_heal_armor:
		return  # Don't heal - already full HP with heal armor

	# Heal the target
	target_unit.receive_heal(heal_amount)
	
	# Spawn healing VFX at target position
	if heal_vfx_scene != null:
		var vfx: Node2D = heal_vfx_scene.instantiate() as Node2D
		if vfx != null:
			# Add to target's parent so it auto-cleans like other VFX
			target_unit.get_parent().add_child(vfx)
			vfx.global_position = target_unit.global_position
	
	# Clear target after healing so we look for a new target
	# DON'T change state here - let the attack animation finish!
	target = null


func _find_nearest_ally_to_follow() -> void:
	"""Find nearest ally to follow when no one needs healing."""
	if friendly_container == null:
		return

	var nav_pos := _get_nav_position()
	var closest_ally: Unit = null
	var closest_distance := INF

	for ally in friendly_container.get_children():
		if not is_instance_valid(ally) or not ally is Unit:
			continue

		var ally_unit := ally as Unit
		if ally_unit == self or ally_unit.state == "dying" or ally_unit is Healer:
			continue  # Skip self, dying units, and other healers

		var ally_nav_pos := ally_unit._get_nav_position()
		var distance := nav_pos.distance_to(ally_nav_pos)
		if distance < closest_distance:
			closest_ally = ally_unit
			closest_distance = distance

	if closest_ally != null:
		var ally_nav_pos := closest_ally._get_nav_position()
		var distance_to_ally := nav_pos.distance_to(ally_nav_pos)

		# If within attack range, just idle
		if distance_to_ally <= (attack_range * 10.0 + 20.0):
			target = null
			if state == "moving":
				set_state("idle")
		else:
			# Move towards nearest ally (but don't attack/heal them)
			target = closest_ally
			set_state("moving")
	else:
		# No allies at all - just idle
		target = null
		if state == "moving":
			set_state("idle")
