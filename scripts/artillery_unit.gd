extends Unit
class_name ArtilleryUnit

## Artillery unit that fires indirect attacks - projectile goes up, lands on target with AOE damage.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0  # Fall speed of the projectile
@export var target_marker_scene: PackedScene
@export var hit_delay := 1.5  # Seconds between animation finish and projectile spawn
@export var splash_radius := 100.0  # Radius for splash damage (0 = no splash, direct hit only)
@export var impact_animation_scene: PackedScene = null  # Optional scene to instantiate on impact

# Queue of pending artillery strikes (allows multiple shots in flight)
# Each entry: { position: Vector2, marker: Node2D }
var _pending_strikes: Array[Dictionary] = []


## Override to filter targets to only those within level bounds (ground targets only)
func _check_for_targets() -> void:
	if enemy_container == null:
		return

	var closest_enemy: Node2D = null
	var closest_distance := INF

	if targets_high_priority:
		# Priority-based targeting: find highest priority, then closest of those
		var highest_priority := -INF
		var high_priority_enemies: Array[Unit] = []
		
		# First pass: find highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			# Filter out targets outside level bounds
			if not _is_position_within_bounds(unit_enemy.global_position):
				continue
			
			var distance := position.distance_to(enemy.position)
			if distance >= detection_range:
				continue
			
			if unit_enemy.priority > highest_priority:
				highest_priority = unit_enemy.priority
		
		# Second pass: collect all enemies with highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			# Filter out targets outside level bounds
			if not _is_position_within_bounds(unit_enemy.global_position):
				continue
			
			var distance := position.distance_to(enemy.position)
			if distance >= detection_range:
				continue
			
			if unit_enemy.priority == highest_priority:
				high_priority_enemies.append(unit_enemy)
		
		# Third pass: find closest among high priority enemies
		for unit_enemy in high_priority_enemies:
			var distance := position.distance_to(unit_enemy.position)
			if distance < closest_distance:
				closest_enemy = unit_enemy
				closest_distance = distance
	else:
		# Normal targeting: just find closest enemy
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			# Only consider Unit nodes as valid targets
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue  # Skip dead or dying units

			# Filter out targets outside level bounds
			if not _is_position_within_bounds(unit_enemy.global_position):
				continue

			var distance := position.distance_to(enemy.position)
			
			# Check if enemy is within detection range
			if distance < detection_range and distance < closest_distance:
				closest_enemy = enemy
				closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		var distance_to_target := position.distance_to(closest_enemy.position)
		
		# If we're in attack range, start fighting
		if distance_to_target <= (attack_range * 10.0 + 20.0):
			set_state("fighting")
			# Reset cooldown timer when entering combat
			var effective_cooldown := _get_effective_cooldown()
			# Artillery units get random delay for first attack to stagger them
			time_since_attack = randf() * effective_cooldown
		# Otherwise, we'll keep moving towards them (state stays "moving")


func _is_position_within_bounds(pos: Vector2) -> bool:
	"""Check if a global position is within the level bounds."""
	var bounds := _get_level_bounds()
	if bounds.is_empty():
		return true  # If no bounds set, allow all targets
	
	var min_y: float = bounds.get("min_y", 0.0) as float
	var max_y: float = bounds.get("max_y", 360.0) as float
	
	return pos.y >= min_y and pos.y <= max_y


## Override to play fire sound and spawn target marker on attack frame
func _trigger_attack_damage() -> void:
	"""Play fire sound and start artillery attack sequence on the attack frame."""
	has_triggered_frame_damage = true
	_play_fire_sound()
	_execute_attack()


## Override to spawn target marker, wait, then spawn falling projectile
## Damage happens when projectile impacts (in ArtilleryProjectile._on_impact())
func _execute_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	
	# Don't spawn projectile if target is already dead/dying
	if target is Unit:
		var target_unit := target as Unit
		if target_unit.current_hp <= 0 or target_unit.state == "dying":
			return
	
	# Don't spawn projectile if combat has ended
	if not _is_combat_active():
		return
	
	if projectile_scene == null:
		push_error("ArtilleryUnit has no projectile_scene assigned!")
		return
	
	# Store this strike's data in the queue
	var strike_position := target.global_position
	var strike_marker := _spawn_target_marker(strike_position)
	
	# Queue this strike
	var strike_data := {
		"position": strike_position,
		"marker": strike_marker
	}
	_pending_strikes.append(strike_data)
	
	# Wait for hit_delay, then spawn the projectile
	# Use a lambda to capture the specific strike data
	get_tree().create_timer(hit_delay).timeout.connect(func(): _spawn_artillery_projectile(strike_data))


func _spawn_target_marker(position: Vector2) -> Node2D:
	if target_marker_scene == null:
		push_warning("ArtilleryUnit has no target_marker_scene assigned!")
		return null
	
	var marker := target_marker_scene.instantiate()
	get_parent().add_child(marker)
	marker.global_position = position
	return marker


func _spawn_artillery_projectile(strike_data: Dictionary) -> void:
	# Remove this strike from the queue
	_pending_strikes.erase(strike_data)
	
	# Get strike data
	var strike_position: Vector2 = strike_data.get("position", Vector2.ZERO)
	var strike_marker: Node2D = strike_data.get("marker", null)
	
	# Spawn projectile
	var projectile: ArtilleryProjectile = projectile_scene.instantiate() as ArtilleryProjectile
	if projectile == null:
		push_error("Failed to instantiate artillery projectile!")
		# Clean up marker if projectile fails
		if strike_marker != null and is_instance_valid(strike_marker):
			strike_marker.queue_free()
		return
	
	# Add to scene tree
	get_parent().add_child(projectile)
	
	# Position off-screen above the target
	# Get the viewport height and position above it
	var viewport_rect := get_viewport_rect()
	var spawn_y := viewport_rect.position.y - 50  # 50 pixels above top of screen
	projectile.global_position = Vector2(strike_position.x, spawn_y)
	
	# Setup projectile
	projectile.setup(strike_position, enemy_container, damage, splash_radius, armor_piercing, is_enemy)
	projectile.speed = projectile_speed
	projectile.target_marker = strike_marker
	projectile.impact_animation_scene = impact_animation_scene
	# Pass impact sound callback to projectile
	projectile.impact_sound_callback = _play_impact_sound
