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

@onready var visible_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	# Connect screen exit signal to destroy projectile
	visible_notifier.screen_exited.connect(queue_free)


func _process(delta: float) -> void:
	# Move in the set direction
	position += direction * speed * delta
	
	# Check for hits
	_check_for_hits()


func _check_for_hits() -> void:
	if enemy_container == null:
		return
	
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
		
		var distance := position.distance_to(enemy.position)
		if distance < hit_radius:
			# Hit! Deal damage and destroy projectile
			_on_impact(position)
			return


func _on_impact(impact_position: Vector2) -> void:
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
	if splash_radius > 0.0:
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
			
			var distance := impact_position.distance_to(enemy.position)
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
		var distance := impact_position.distance_to(enemy.position)
		if distance <= splash_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, armor_piercing)


## Initialize the projectile with direction and target container
func setup(dir: Vector2, targets: Node2D, dmg: int, pierce: bool = false, fired_by_enemy_unit: bool = false) -> void:
	direction = dir.normalized()
	enemy_container = targets
	damage = dmg
	armor_piercing = pierce
	fired_by_enemy = fired_by_enemy_unit
	
	# Rotate sprite to face direction
	rotation = direction.angle()
