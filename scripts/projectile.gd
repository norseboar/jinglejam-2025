extends Node2D
class_name Projectile

## Projectile fired by ranged units. Moves in a direction until it hits an enemy or leaves the screen.

var speed := 400.0  # Set by unit that creates this projectile
var damage := 1  # Set by unit that creates this projectile
@export var hit_radius := 20.0  # How close to an enemy to count as a hit
var splash_radius := 0.0  # Radius for splash damage (0 = no splash, direct hit only)
var impact_animation_scene: PackedScene = null  # Optional scene to instantiate on impact

var direction := Vector2.RIGHT
var enemy_container: Node2D = null  # Container of valid targets
var armor_piercing := false  # Set by unit that creates this projectile
var impact_sound_callback: Callable  # Callback to play impact sound (set by unit)
var fired_by_enemy := false  # true if fired by enemy unit, false if fired by player unit

# Optional sine-wave motion perpendicular to travel direction
@export var sine_amplitude: float = 0.0
@export var sine_frequency: float = 0.0  # cycles per second

# Optional travel-to-point arc motion
var use_target_position: bool = false
var target_position: Vector2 = Vector2.ZERO
var arc_amplitude: float = 0.0
var ignore_collisions_until_target: bool = false
var aoe_only: bool = false  # When true, skip direct-hit damage on impact

# Internal state for motion paths
var _time_alive: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _target_direction: Vector2 = Vector2.ZERO
var _target_distance: float = 0.0
var _distance_traveled: float = 0.0
var _last_sine_offset: Vector2 = Vector2.ZERO
var _last_arc_offset: Vector2 = Vector2.ZERO

@onready var visible_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	# Connect screen exit signal to destroy projectile
	visible_notifier.screen_exited.connect(queue_free)


func _process(delta: float) -> void:
	_time_alive += delta
	
	if use_target_position:
		_process_target_motion(delta)
	else:
		_process_directional_motion(delta)


func _check_for_hits() -> void:
	if enemy_container == null:
		return
	
	var proj_pos := global_position
	
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		
		# Skip other projectiles - projectiles should ignore each other
		if enemy is Projectile:
			continue
		
		# Skip dead or dying units
		if enemy is Unit:
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			# Only hit units with opposite team (prevent friendly fire)
			# If fired by enemy, only hit player units (is_enemy = false)
			# If fired by player, only hit enemy units (is_enemy = true)
			if unit_enemy.is_enemy == fired_by_enemy:
				continue  # Same team, skip
		
		var distance := proj_pos.distance_to(enemy.global_position)
		if distance < hit_radius:
			# Hit! Deal damage and destroy projectile
			_on_impact(proj_pos)
			return


func _on_impact(impact_position: Vector2, force_splash: bool = false) -> void:
	# Play impact sound
	if impact_sound_callback.is_valid():
		impact_sound_callback.call()
	
	# Spawn impact animation if provided
	if impact_animation_scene != null:
		var anim_instance := impact_animation_scene.instantiate()
		if anim_instance != null:
			get_parent().add_child(anim_instance)
			anim_instance.global_position = impact_position
	
	# Don't deal damage if combat is over
	if not _is_combat_active():
		queue_free()
		return
	
	# Deal damage
	if splash_radius > 0.0 or force_splash or aoe_only:
		# Splash damage - damage everything in radius
		_deal_splash_damage(impact_position)
	else:
		# Direct hit - find the closest enemy and damage it
		var closest_enemy = null
		var closest_distance := hit_radius
		
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			
			# Skip other projectiles
			if enemy is Projectile or enemy is ArtilleryProjectile:
				continue
			
			# Skip dead or dying units
			if enemy is Unit:
				var unit_enemy := enemy as Unit
				if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
					continue
				
				# Only hit units with opposite team
				if unit_enemy.is_enemy == fired_by_enemy:
					continue
			
			var distance := impact_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
		
		if closest_enemy != null and closest_enemy.has_method("take_damage"):
			closest_enemy.take_damage(damage, armor_piercing)
	
	# Destroy the projectile
	queue_free()


func _is_combat_active() -> bool:
	"""Check if combat is still active by finding the Game node and checking phase."""
	var game: Game = get_tree().get_first_node_in_group("game") as Game
	if game == null:
		# If we can't find the game node, assume combat is active (fail-safe)
		return true
	
	return game.phase == "battle"


func _deal_splash_damage(impact_position: Vector2) -> void:
	"""Deal splash damage to all enemies within splash_radius."""
	if enemy_container == null:
		return
	
	# Don't deal damage if combat is over
	if not _is_combat_active():
		return
	
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		
		# Skip other projectiles
		if enemy is Projectile or enemy is ArtilleryProjectile:
			continue
		
		# Skip dead or dying units
		if enemy is Unit:
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			# Only hit units with opposite team
			if unit_enemy.is_enemy == fired_by_enemy:
				continue
		
		# Check if enemy is within splash radius
		var distance := impact_position.distance_to(enemy.global_position)
		if distance <= splash_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, armor_piercing)


## Initialize the projectile with direction and target container
func setup(dir: Vector2, targets: Node2D, dmg: int, pierce: bool = false, fired_by_enemy_unit: bool = false, use_target: bool = false, target_pos: Vector2 = Vector2.ZERO, arc_amp: float = 0.0, ignore_until_target: bool = false, force_aoe_only: bool = false) -> void:
	direction = dir.normalized()
	enemy_container = targets
	damage = dmg
	armor_piercing = pierce
	fired_by_enemy = fired_by_enemy_unit
	use_target_position = use_target
	target_position = target_pos
	arc_amplitude = arc_amp
	ignore_collisions_until_target = ignore_until_target
	aoe_only = force_aoe_only
	_start_position = global_position
	_last_sine_offset = Vector2.ZERO
	_last_arc_offset = Vector2.ZERO
	
	if use_target_position:
		_target_direction = (target_position - _start_position).normalized()
		_target_distance = _start_position.distance_to(target_position)
		direction = _target_direction
	
	# Rotate sprite to face direction
	rotation = direction.angle()


func _process_directional_motion(delta: float) -> void:
	var displacement: Vector2 = direction * speed * delta
	
	if sine_amplitude != 0.0 and sine_frequency > 0.0:
		var omega := TAU * sine_frequency
		var perp := Vector2(-direction.y, direction.x)
		var phase := _time_alive * omega
		var current_sine := perp * sine_amplitude * sin(phase)
		var sine_adjust := current_sine - _last_sine_offset
		_last_sine_offset = current_sine
		displacement += sine_adjust
	
	position += displacement
	_check_for_hits()


func _process_target_motion(delta: float) -> void:
	if _target_distance <= 0.0:
		_on_impact(global_position, true)
		return
	
	var desired_forward := speed * delta
	var target_remaining := _target_distance - _distance_traveled
	var omega := 0.0
	if sine_frequency > 0.0:
		omega = TAU * sine_frequency
	var t_next := _time_alive + delta
	
	var arc_perp := Vector2.UP  # keep arc upward in screen space
	var sine_perp := Vector2(-_target_direction.y, _target_direction.x)  # sine remains perpendicular to travel
	
	# First guess progress using desired forward
	var progress_guess := clampf((_distance_traveled + desired_forward) / _target_distance, 0.0, 1.0)
	var arc_offset_new := Vector2.ZERO
	if arc_amplitude != 0.0:
		arc_offset_new = arc_perp * sin(PI * progress_guess) * arc_amplitude
	
	var sine_offset_new := Vector2.ZERO
	if sine_amplitude != 0.0 and omega != 0.0:
		sine_offset_new = sine_perp * sine_amplitude * sin(t_next * omega)
	
	var offset_delta := (arc_offset_new - _last_arc_offset) + (sine_offset_new - _last_sine_offset)
	var forward_mag := sqrt(max((desired_forward * desired_forward) - offset_delta.length_squared(), 0.0))
	forward_mag = min(forward_mag, target_remaining)
	
	var progress := clampf((_distance_traveled + forward_mag) / _target_distance, 0.0, 1.0)
	if arc_amplitude != 0.0:
		arc_offset_new = arc_perp * sin(PI * progress) * arc_amplitude
		offset_delta = (arc_offset_new - _last_arc_offset) + (sine_offset_new - _last_sine_offset)
		forward_mag = sqrt(max((desired_forward * desired_forward) - offset_delta.length_squared(), 0.0))
		forward_mag = min(forward_mag, target_remaining)
		progress = clampf((_distance_traveled + forward_mag) / _target_distance, 0.0, 1.0)
	
	var displacement := _target_direction * forward_mag + offset_delta
	position += displacement
	_distance_traveled += forward_mag
	_last_arc_offset = arc_offset_new
	_last_sine_offset = sine_offset_new
	
	if progress >= 1.0 or _distance_traveled >= _target_distance:
		_on_impact(target_position, true)
	elif not ignore_collisions_until_target:
		_check_for_hits()
