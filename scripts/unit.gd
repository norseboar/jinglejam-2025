extends Node2D
class_name Unit

const DamageNumberScene = preload("res://scenes/vfx/damage_number.tscn")

# Signals
signal enemy_unit_died(gold_reward: int, death_position: Vector2)  # Emitted by enemies with gold_reward and position
signal player_unit_died(army_index: int)  # Emitted by player units with army_index

# Stats
@export var max_hp := 3
@export var damage := 1
@export var speed := 100.0           # pixels per second
@export var attack_range := 50.0     # radius to attack enemies
@export var detection_range := 2000.0 # radius to detect enemies (very large to cover screen)
@export var attack_cooldown := 3.0   # seconds to wait in idle after attack animation completes (0 = no cooldown)
@export var attack_speed := 0  # Attack speed stat (reduces cooldown by 0.5 seconds per point)
@export var attack_damage_frame := 0 # Frame number in attack animation when damage is dealt
@export var priority := 1            # Priority for targeting (higher = more important)
@export var armor := 0               # Damage reduction (subtracted from incoming damage)
@export var armor_piercing := false  # If true, attacks ignore enemy armor
@export var targets_high_priority := false  # If true, only targets highest priority enemies
@export var heal_amount := 0         # Heal amount (only used by Healer units)
@export var heal_armor_duration := 1.0 # How long heal armor lasts in seconds
var heal_armor := 0                  # Temporary armor from healing (reduces damage)
@export var fly_height := -1        # Height from top of screen to fly to at battle start (-1 = disabled)

# Separation behavior (anti-clumping)
@export var enable_separation := true          # Toggle separation behavior on/off
@export var separation_radius := 40.0          # How far to check for nearby allies
@export var separation_strength := 150.0       # How strong the push-away force is

# Display info
@export var display_name: String = "Unit"
@export var description: String = "A basic unit."

# Gold system properties
@export var base_recruit_cost := 10  # Base cost to recruit this unit type
@export var upgrade_cost := 5  # Cost per upgrade (HP or Damage)

# Upgrade system
@export var available_upgrades: Array[UnitUpgrade] = []

# Sound effects
@export var damage_sounds: Array[AudioStream] = [
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 1.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 2.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 3.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 5.wav")
]  # List of damage sound effects to randomly choose from (for melee units)

@export var fire_sounds: Array[AudioStream] = []  # List of fire sound effects for ranged units (plays on attack frame)
@export var impact_sounds: Array[AudioStream] = []  # List of impact sound effects for ranged units (plays when projectile hits)

# State
var current_hp := 3
var is_enemy := false        # true = moves left (enemy), false = moves right (player)
var state := "idle"          # "idle" | "moving" | "fighting" | "dying"
var target: Node2D = null    # current attack target
var time_since_attack := 0.0 # timer for attack cooldown
var is_attacking := false    # true when attack animation is playing
var has_triggered_frame_damage := false  # Prevents multiple damage triggers per attack
var army_index := -1         # Index in Game.army array, or -1 if not from army
var has_reached_fly_height := false  # True when unit has reached its fly_height target
var heal_armor_timer := 0.0  # Time remaining on heal armor (in seconds)
var battle_start_time := 0   # Time (msec) when unit first started moving (for stagger timing)
var has_done_first_combat_entry := false  # True after first time entering combat this battle

# Upgrades
var upgrades: Dictionary = {}  # e.g., { "hp": 2, "damage": 1 }

# Reference to the container holding enemies (set by Game.gd when spawning)
var enemy_container: Node2D = null

# Reference to the container holding friendly units (set by Game.gd when spawning)
var friendly_container: Node2D = null

# Reference to the spawn slot this unit is placed on (for re-dragging during preparation)
var spawn_slot: SpawnSlot = null

# Navigation system
var navigation_agent: NavigationAgent2D = null  # Optional - only exists for ground units, set in _ready()
var initial_y_position: float = 0.0  # Stored Y position for end zone calculation
var has_line_of_sight_to_target: bool = false  # Whether current target has clear LOS
@export var navigation_center: Node2D = null  # Optional - Node2D offset for pathfinding center

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var healthbar: Healthbar = $Healthbar
@onready var drag_handle: Control = $DragHandle


func _ready() -> void:
	current_hp = max_hp

	# Get NavigationAgent2D if it exists (optional - only ground units have it)
	# Look for it as a child of navigation_center if that exists, otherwise look for it directly
	if navigation_center:
		navigation_agent = navigation_center.get_node_or_null("NavigationAgent2D")
	else:
		navigation_agent = get_node_or_null("NavigationAgent2D")

	# Initialize healthbar
	if healthbar:
		healthbar.set_alignment(is_enemy)
		healthbar.update_health(current_hp, max_hp)

	# Initialize upgrade markers visibility
	_update_upgrade_markers()

	# Flip sprite to face correct direction based on team
	# This must happen in _ready() so enemies face the correct direction immediately
	if animated_sprite:
		animated_sprite.flip_h = is_enemy
		_safe_play_animation("idle")
		# Connect to frame_changed signal to detect attack damage frame
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)


func _process(delta: float) -> void:
	# Always increment time since last attack (tracks cooldown across all states)
	# Keep counting even during attack animations
	time_since_attack += delta
	
	# Tick down heal armor timer
	if heal_armor > 0:
		heal_armor_timer -= delta
		if heal_armor_timer <= 0.0:
			heal_armor = 0
			heal_armor_timer = 0.0

	match state:
		"idle":
			pass  # Do nothing, waiting for battle to start
		"moving":
			_do_movement(delta)
		"fighting":
			_do_fighting()
		"dying":
			pass  # Do nothing, unit is fading out


func set_state(new_state: String) -> void:
	if state == new_state:
		return
	
	# Reset attacking flag if leaving fighting state
	if state == "fighting" and new_state != "fighting":
		is_attacking = false
	
	# Reset fly height flag only when transitioning from idle to moving (battle starts)
	# Don't reset when transitioning from fighting to moving (after attacks)
	if state == "idle" and new_state == "moving":
		has_reached_fly_height = false
		# Record battle start time for stagger timing
		battle_start_time = Time.get_ticks_msec()
		# Reset first combat entry flag for new battle
		has_done_first_combat_entry = false
	
	state = new_state
	match state:
		"idle":
			_safe_play_animation("idle")
		"moving":
			_safe_play_animation("walk")
		"fighting":
			_safe_play_animation("idle")  # Play idle while waiting between attacks
		"dying":
			_safe_play_animation("idle")  # Play idle animation while dying


func _do_movement(delta: float) -> void:
	# If unit has fly_height set and hasn't reached it yet, fly to that height first
	if fly_height >= 0 and not has_reached_fly_height:
		var viewport_rect := get_viewport_rect()
		var target_y := viewport_rect.position.y + fly_height  # fly_height is from top of screen
		var current_y := position.y
		
		# Check if we've reached the target height (with small threshold)
		if abs(current_y - target_y) < 5.0:
			# Snap to exact position and mark as reached
			position.y = target_y
			has_reached_fly_height = true
		else:
			# Fly towards target height
			var direction_y := -1.0 if current_y > target_y else 1.0  # Negative = up, positive = down
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
	
	# Check for enemies first
	_check_for_targets()
	
	# Determine where to move
	var nav_target := _get_navigation_target()
	
	# Flying units ignore navigation and move directly (fly_height >= 0 means flying)
	if fly_height >= 0:
		var direction_to_target := (nav_target - global_position).normalized()
		var movement := direction_to_target * speed * 10.0 * delta
		position += movement
		animated_sprite.flip_h = direction_to_target.x < 0
		return
	
	# Ground units (fly_height < 0) use navigation pathfinding
	# NavigationAgent2D should exist for all ground units
	if navigation_agent == null:
		push_error("[Navigation] Ground unit '%s' missing NavigationAgent2D node! Cannot pathfind." % name)
		return  # Don't move if no navigation agent
	
	# Check if navigation map is available
	if not navigation_agent.is_navigation_finished() and navigation_agent.get_navigation_map() == RID():
		push_warning("[Navigation] Unit '%s' navigation map not ready yet. Position: %s" % [name, global_position])
		return
	
	# Always update target position (agent will recalculate path if needed)
	if navigation_agent.target_position.distance_to(nav_target) > 1.0:
		navigation_agent.target_position = nav_target
	
	# Get navigation position (use navigation_center if set, otherwise use unit position)
	var nav_position := _get_nav_position()
	
	# Check distance to target
	var distance_to_target := nav_target.distance_to(nav_position)
	if distance_to_target <= 5.0:
		# Close enough to target, don't move
		return
	
	# Try to get next position on path
	var next_path_position := navigation_agent.get_next_path_position()
	var distance_to_next := next_path_position.distance_to(nav_position)
	
	# Follow navigation path if we have a valid one
	if distance_to_next > 1.0:
		# We have a valid path, follow it
		var direction: Vector2 = (next_path_position - nav_position).normalized()
		var movement: Vector2 = direction * speed * 10.0 * delta
		var separation: Vector2 = _apply_separation_force() * delta
		position += movement + separation
		animated_sprite.flip_h = direction.x < 0
	else:
		# No valid path - log why
		if navigation_agent.is_navigation_finished():
			# Pathfinding finished but we're not at target - might be stuck
			push_warning("[Navigation] Unit '%s' navigation finished but not at target. Target: %s, Current: %s, Distance: %.1f" % [name, nav_target, global_position, distance_to_target])
		else:
			# Pathfinding in progress but no next position - might be unreachable or nav map issue
			push_warning("[Navigation] Unit '%s' has no valid path. Target: %s, Current: %s, Nav map: %s" % [name, nav_target, global_position, navigation_agent.get_navigation_map()])


func _apply_separation_force() -> Vector2:
	"""Calculate repulsion force from nearby friendly units to prevent clumping."""
	if not enable_separation or friendly_container == null:
		return Vector2.ZERO
	
	var nav_pos := _get_nav_position()
	var separation_force := Vector2.ZERO
	var nearby_count := 0
	
	# Check all friendly units
	for ally in friendly_container.get_children():
		if not is_instance_valid(ally) or ally == self:
			continue
		if not ally is Unit:
			continue
		
		var ally_unit := ally as Unit
		# Skip dead/dying units
		if ally_unit.state == "dying" or ally_unit.current_hp <= 0:
			continue
		
		var ally_nav_pos := ally_unit._get_nav_position()
		var distance := nav_pos.distance_to(ally_nav_pos)
		
		# If within separation radius, add repulsion force
		if distance < separation_radius and distance > 0.1:  # Avoid divide by zero
			# Direction away from ally
			var away_direction := (nav_pos - ally_nav_pos).normalized()
			# Stronger force when closer (inverse square)
			var force_magnitude := separation_strength * (1.0 - distance / separation_radius)
			separation_force += away_direction * force_magnitude
			nearby_count += 1
	
	# Average the force if multiple neighbors
	if nearby_count > 0:
		separation_force /= nearby_count
	
	return separation_force


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

			var distance := position.distance_to(enemy.position)
			
			# Check if enemy is within detection range
			if distance < detection_range and distance < closest_distance:
				closest_enemy = enemy
				closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		
		# Check line of sight (unless we're artillery - they ignore obstacles)
		if self is ArtilleryUnit:
			has_line_of_sight_to_target = true  # Artillery always has LOS
		else:
			has_line_of_sight_to_target = has_clear_line_of_sight_to(target as Unit)
		
		var distance_to_target := position.distance_to(closest_enemy.position)
		
		# If we're in attack range AND have line of sight, start fighting
		# (Ranged units need LOS to shoot, melee just need to be in range)
		var can_attack := distance_to_target <= (attack_range * 10.0 + 20.0)
		if attack_range < 100:  # Melee unit
			can_attack = can_attack  # Just needs range, not LOS
		else:  # Ranged unit
			can_attack = can_attack and has_line_of_sight_to_target
		
		if can_attack:
			set_state("fighting")
			
			# Only set initial attack timing on FIRST combat entry in this battle
			if not has_done_first_combat_entry:
				has_done_first_combat_entry = true
				# Apply stagger delay in the first 0.25 seconds of battle to prevent all units firing at once
				var time_since_battle_start := (Time.get_ticks_msec() - battle_start_time) / 1000.0
				if time_since_battle_start < 0.25:
					# Artillery gets longer stagger (0-0.5s) to spread out their shots more
					var stagger_max := 0.5 if self is ArtilleryUnit else 0.25
					time_since_attack = randf() * stagger_max
				else:
					time_since_attack = 999.0  # Large value = attack immediately
			# After first combat entry, time_since_attack continues tracking naturally
		# Otherwise, we'll keep moving towards them (state stays "moving")
	else:
		# No target, clear LOS flag
		has_line_of_sight_to_target = false


func _do_fighting() -> void:
	# If we're already attacking, COMMIT to the attack - don't interrupt the animation
	# This prevents units from snapping out of attack animations mid-swing
	if is_attacking:
		return
	
	# Before starting a new attack, check if target is still valid
	if not is_instance_valid(target) or not target is Unit:
		target = null
		set_state("moving")
		return
	
	var target_unit := target as Unit
	if target_unit.current_hp <= 0 or target_unit.state == "dying":
		target = null
		set_state("moving")
		return

	# Check if target moved out of attack range
	var distance := position.distance_to(target.position)
	if distance > (attack_range * 10.0 + 20.0) * 1.2:  # Small buffer to prevent flickering
		# Keep the target but switch to moving so we can move towards them
		set_state("moving")
		return

	# Attack when cooldown has passed (time_since_attack increments in _process)
	var effective_cooldown := _get_effective_cooldown()
	if effective_cooldown <= 0.0 or time_since_attack >= effective_cooldown:
		_attack_target()


func _attack_target() -> void:
	if target == null or not is_instance_valid(target) or is_attacking:
		return

	# Set attacking flag and reset frame damage trigger
	is_attacking = true
	has_triggered_frame_damage = false
	
	# Play attack animation at normal speed (no scaling)
	animated_sprite.speed_scale = 1.0
	_safe_play_animation("attack")

	# Get animation duration at normal speed
	var anim_duration := _get_attack_animation_duration()
	
	if anim_duration > 0:
		get_tree().create_timer(anim_duration).timeout.connect(_on_attack_animation_finished)
	else:
		_on_attack_animation_finished()


func _get_attack_animation_duration() -> float:
	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation("attack"):
		return 0.0
	
	var frame_count := sprite_frames.get_frame_count("attack")
	var anim_speed := sprite_frames.get_animation_speed("attack")
	var anim_duration := 0.0
	
	for i in range(frame_count):
		var frame_duration_frames := sprite_frames.get_frame_duration("attack", i)
		var frame_duration_seconds := frame_duration_frames / anim_speed
		anim_duration += frame_duration_seconds
	
	return anim_duration


func _on_attack_animation_finished() -> void:
	"""Called when attack animation completes. Resets state and switches back to idle."""
	is_attacking = false
	
	# Switch back to idle animation
	# If effective_cooldown > 0, we'll wait in idle for that duration before next attack
	if state == "fighting" and animated_sprite:
		_safe_play_animation("idle")
		# Reset cooldown timer - it will count up during idle animation
		var effective_cooldown := _get_effective_cooldown()
		if effective_cooldown > 0.0:
			time_since_attack = 0.0


func _on_animation_frame_changed() -> void:
	"""Called when AnimatedSprite2D frame changes. Checks if we're on the attack damage frame."""
	if not is_attacking:
		return
	
	# Only trigger on attack animation
	if animated_sprite.animation != "attack":
		return
	
	# Check if we're on the damage frame and haven't triggered yet
	if animated_sprite.frame == attack_damage_frame and not has_triggered_frame_damage:
		_trigger_attack_damage()


## Virtual method - subclasses override to customize behavior on attack frame
## Melee units: play damage sound and deal damage
## Ranged units: play fire sound and spawn projectile
func _trigger_attack_damage() -> void:
	"""Called on the attack damage frame. Default behavior handles melee attacks."""
	has_triggered_frame_damage = true
	_execute_attack()


## Virtual method - subclasses override this to implement their attack type
## Melee units: deal damage directly to target
## Ranged units: spawn projectiles (damage happens when projectiles hit)
## Default implementation does nothing - subclasses must override
func _execute_attack() -> void:
	# Base implementation does nothing - subclasses override
	pass


func _get_nav_position() -> Vector2:
	"""Get the navigation position (navigation_center if set, otherwise global_position)."""
	return navigation_center.global_position if navigation_center else global_position


func _is_combat_active() -> bool:
	"""Check if combat is still active by finding the Game node and checking phase."""
	var game: Game = get_tree().get_first_node_in_group("game") as Game
	if game == null:
		# If we can't find the game node, assume combat is active (fail-safe)
		return true
	
	return game.phase == "battle"


func has_clear_line_of_sight_to(target_unit: Unit) -> bool:
	"""Check if there's a clear line of sight to the target unit.
	Uses raycasting on Layer 1 (TotalBlockers) only.
	Ground and flying units can shoot over Layer 2 (MovementBlockers)."""
	if target_unit == null or not is_instance_valid(target_unit):
		return false
	
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target_unit.global_position)
	query.collision_mask = 1  # Layer 1 only (TotalBlockers)
	query.exclude = [self]  # Don't hit ourselves
	
	var result := space_state.intersect_ray(query)
	return result.is_empty()  # Clear if no collision


func _get_navigation_target() -> Vector2:
	"""Determine where the unit should move toward.
	Finds closest enemy (respecting priority targeting), preferring enemies with LOS."""
	
	if enemy_container == null:
		# No enemies to target, stay in place
		return _get_nav_position()
	
	var nav_pos := _get_nav_position()
	var closest_with_los: Unit = null
	var closest_with_los_distance := INF
	var closest_without_los: Unit = null
	var closest_without_los_distance := INF
	
	if targets_high_priority:
		# Priority-based targeting: find highest priority enemies first
		var highest_priority := -INF
		
		# First pass: find highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy) or not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			if unit_enemy.priority > highest_priority:
				highest_priority = unit_enemy.priority
		
		# Second pass: find closest with/without LOS among highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy) or not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			if unit_enemy.priority != highest_priority:
				continue
			
			var enemy_nav_pos := unit_enemy._get_nav_position()
			var distance := nav_pos.distance_to(enemy_nav_pos)
			var has_los := (self is ArtilleryUnit) or has_clear_line_of_sight_to(unit_enemy)
			
			if has_los and distance < closest_with_los_distance:
				closest_with_los = unit_enemy
				closest_with_los_distance = distance
			elif distance < closest_without_los_distance:
				closest_without_los = unit_enemy
				closest_without_los_distance = distance
	else:
		# Normal targeting: just find closest enemy with/without LOS
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy) or not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			var enemy_nav_pos := unit_enemy._get_nav_position()
			var distance := nav_pos.distance_to(enemy_nav_pos)
			var has_los := (self is ArtilleryUnit) or has_clear_line_of_sight_to(unit_enemy)
			
			if has_los and distance < closest_with_los_distance:
				closest_with_los = unit_enemy
				closest_with_los_distance = distance
			elif distance < closest_without_los_distance:
				closest_without_los = unit_enemy
				closest_without_los_distance = distance
	
	# Prefer enemy with LOS, otherwise move toward closest without LOS
	if closest_with_los != null:
		return closest_with_los._get_nav_position()
	elif closest_without_los != null:
		return closest_without_los._get_nav_position()
	
	# No enemies found, stay in place
	return nav_pos


func take_damage(amount: int, attacker_armor_piercing: bool = false) -> void:
	# Ignore damage if already dead/dying
	if state == "dying" or current_hp <= 0:
		return

	# Don't take damage if combat is over
	if not _is_combat_active():
		return

	# Apply armor + heal_armor reduction unless attacker has armor piercing
	var final_damage := amount
	if not attacker_armor_piercing:
		var total_armor := armor + heal_armor
		final_damage = max(0, amount - total_armor)

	# Spawn damage number
	_spawn_damage_number(final_damage)

	current_hp -= final_damage

	# Update healthbar
	if healthbar:
		healthbar.update_health(current_hp, max_hp)

	# Visual feedback: flash the sprite red
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		# Reset color after a short delay
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if current_hp <= 0:
		die()


func _spawn_number(amount: int, number_type: String = "damage", horizontal_offset: float = 0.0) -> void:
	"""Spawn a floating number at this unit's position with the specified type and optional horizontal offset."""
	var number := DamageNumberScene.instantiate()

	# Calculate spawn position at the top of the sprite
	var spawn_position := global_position
	if animated_sprite:
		# Get sprite bounds
		var sprite_height := 16.0  # Default fallback
		if animated_sprite.sprite_frames:
			var current_animation := animated_sprite.animation
			if animated_sprite.sprite_frames.has_animation(current_animation):
				var frame_count := animated_sprite.sprite_frames.get_frame_count(current_animation)
				if frame_count > 0:
					var frame_texture := animated_sprite.sprite_frames.get_frame_texture(current_animation, 0)
					if frame_texture:
						sprite_height = frame_texture.get_height()

		# Position at top of sprite with optional horizontal offset
		spawn_position = animated_sprite.global_position + Vector2(horizontal_offset, -sprite_height / 2)

	# Set position BEFORE adding as child (so _ready() sees correct position)
	number.global_position = spawn_position

	# Setup the number BEFORE adding as child (so _ready() can use the setup data)
	number.setup(amount, number_type)

	# Find the parent container to add the number to
	# We want to add it to the same level as units (not as a child of this unit)
	var world_container: Node2D = null
	if is_enemy and enemy_container != null:
		world_container = enemy_container.get_parent()
	elif not is_enemy and friendly_container != null:
		world_container = friendly_container.get_parent()

	if world_container == null:
		# Fallback: use parent
		world_container = get_parent()

	# Add to world - this triggers _ready() which starts the animation
	world_container.add_child(number)


func _spawn_damage_number(damage_amount: int) -> void:
	"""Spawn a floating damage number at this unit's position."""
	_spawn_number(damage_amount, "damage")


func receive_heal(amount: int) -> void:
	# Ignore heal if already dead/dying
	if state == "dying" or current_hp <= 0:
		return

	# Calculate actual heal amount (may be clamped to max HP)
	var old_hp := current_hp
	current_hp = min(current_hp + amount, max_hp)
	var actual_heal := current_hp - old_hp

	# Apply heal armor = half of heal amount (not stacking, just refresh)
	var shield_amount: int = int(floor(amount / 2.0))
	heal_armor = shield_amount
	heal_armor_timer = heal_armor_duration

	# Spawn healing numbers: heal amount (green) and shield amount (cyan/blue)
	# Always show heal number if we attempted to heal (even if 0 due to being at max HP)
	if amount > 0:
		_spawn_number(actual_heal, "heal", -10.0)  # Heal number, offset left
	# Always show shield number if shield was applied
	if shield_amount > 0:
		_spawn_number(shield_amount, "shield", 10.0)  # Shield number, offset right

	# Update healthbar
	if healthbar:
		healthbar.update_health(current_hp, max_hp)

	# Visual feedback: flash the sprite green
	if animated_sprite:
		animated_sprite.modulate = Color.GREEN
		get_tree().create_timer(0.1).timeout.connect(_reset_color)


func _reset_color() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func die() -> void:
	# Prevent multiple calls to die()
	if state == "dying":
		return
	
	# Stop all movement and combat
	is_attacking = false
	target = null
	set_state("dying")
	
	# Emit appropriate signal based on unit type
	if is_enemy:
		var gold_reward := _calculate_gold_reward()
		enemy_unit_died.emit(gold_reward, global_position)
	else:
		# Emit signal for player unit death (to remove from army)
		if army_index >= 0:
			player_unit_died.emit(army_index)
	
	# Fade out before removing from scene
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func apply_upgrades() -> void:
	"""Apply upgrade bonuses to base stats and update visual markers."""
	for upgrade_index in upgrades:
		# Upgrade keys should always be integers (indices into available_upgrades)
		if not upgrade_index is int:
			push_error("Invalid upgrade key type (expected int, got %s): %s" % [typeof(upgrade_index), upgrade_index])
			continue
		
		var count: int = upgrades[upgrade_index]

		# Get the upgrade definition
		if upgrade_index < 0 or upgrade_index >= available_upgrades.size():
			push_error("Invalid upgrade index: %d (available_upgrades size: %d)" % [upgrade_index, available_upgrades.size()])
			continue

		var upgrade: UnitUpgrade = available_upgrades[upgrade_index]
		var total_amount := upgrade.amount * count

		# Apply based on stat type
		match upgrade.stat_type:
			UnitUpgrade.StatType.MAX_HP:
				max_hp += total_amount
				current_hp = max_hp  # Refresh to new max
			UnitUpgrade.StatType.DAMAGE:
				damage += total_amount
			UnitUpgrade.StatType.SPEED:
				speed += total_amount
			UnitUpgrade.StatType.ATTACK_RANGE:
				attack_range += total_amount
			UnitUpgrade.StatType.ATTACK_SPEED:
				attack_speed += total_amount
			UnitUpgrade.StatType.ARMOR:
				armor += total_amount
			UnitUpgrade.StatType.HEAL_AMOUNT:
				heal_amount += total_amount

	_update_upgrade_markers()


func _get_effective_cooldown() -> float:
	"""Calculate effective cooldown: base cooldown minus attack speed bonus."""
	var effective := attack_cooldown - (attack_speed * 0.5)
	return max(0.0, effective)  # Ensure cooldown never goes below 0


func _calculate_gold_reward() -> int:
	"""Calculate gold reward based on unit cost and upgrades."""
	var total_upgrades := 0
	for count in upgrades.values():
		total_upgrades += count
	var total_cost := base_recruit_cost + (upgrade_cost * total_upgrades)
	
	# Get the percentage from Game
	var game: Game = get_tree().get_first_node_in_group("game") as Game
	var percentage := 0.5  # Default fallback
	if game != null:
		percentage = game.unit_value_percentage
	
	return int(total_cost * percentage)


func _safe_play_animation(anim_name: String) -> void:
	"""Safely play an animation, checking if it exists first."""
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)


func _play_damage_sound() -> void:
	"""Play a random damage sound effect from the damage_sounds array."""
	if damage_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % damage_sounds.size()
	var sound: AudioStream = damage_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _play_fire_sound() -> void:
	"""Play a random fire sound effect from the fire_sounds array."""
	if fire_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % fire_sounds.size()
	var sound: AudioStream = fire_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _play_impact_sound() -> void:
	"""Play a random impact sound effect from the impact_sounds array."""
	if impact_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % impact_sounds.size()
	var sound: AudioStream = impact_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _update_upgrade_markers() -> void:
	"""Show the appropriate upgrade marker based on total upgrade count."""
	var upgrade_markers := get_node_or_null("UpgradeMarkers")
	if upgrade_markers == null:
		return
	
	var background := upgrade_markers.get_node_or_null("Background") as Sprite2D
	var marker_1 := upgrade_markers.get_node_or_null("Marker1") as Sprite2D
	var marker_2 := upgrade_markers.get_node_or_null("Marker2") as Sprite2D
	var marker_3 := upgrade_markers.get_node_or_null("Marker3") as Sprite2D
	
	if marker_1 == null or marker_2 == null or marker_3 == null:
		return
	
	var total := 0
	for count in upgrades.values():
		total += count
	
	# Show background if there are any upgrades
	if background != null:
		background.visible = (total > 0)
	
	# Show the appropriate marker sprite (only one at a time)
	marker_1.visible = (total == 1)
	marker_2.visible = (total == 2)
	marker_3.visible = (total >= 3)
