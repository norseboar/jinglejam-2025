extends Node2D
class_name ArtilleryProjectile

## Projectile that falls from the sky and deals AOE damage on impact.

var speed := 400.0  # Fall speed, set by spawning unit
var damage := 1  # Set by spawning unit
var splash_radius := 100.0  # Radius for splash damage (0 = no splash, direct hit only)
var armor_piercing := false  # Set by spawning unit
var impact_animation_scene: PackedScene = null  # Optional scene to instantiate on impact

var target_position := Vector2.ZERO  # Where the projectile will land
var enemy_container: Node2D = null  # Container of valid targets
var impact_sound_callback: Callable  # Callback to play impact sound (set by unit)
var fired_by_enemy := false  # true if fired by enemy unit, false if fired by player unit

var target_marker: Node2D = null  # Reference to the marker to remove on impact


func _process(delta: float) -> void:
	# Move straight down
	position.y += speed * delta
	
	# Check if we've reached the target Y position
	if position.y >= target_position.y:
		_on_impact()


func _on_impact() -> void:
	# Play impact sound
	if impact_sound_callback.is_valid():
		impact_sound_callback.call()
	
	# Spawn impact animation if provided
	if impact_animation_scene != null:
		var anim_instance := impact_animation_scene.instantiate()
		if anim_instance != null:
			get_parent().add_child(anim_instance)
			anim_instance.global_position = target_position
	
	# Deal damage
	if splash_radius > 0.0:
		# Splash damage - damage everything in radius
		_deal_splash_damage(target_position)
	else:
		# Direct hit - find the closest enemy and damage it
		var closest_enemy = null
		var closest_distance := 999999.0
		
		if enemy_container != null:
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
				
				var distance := target_position.distance_to(enemy.position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = enemy
		
		if closest_enemy != null and closest_enemy.has_method("take_damage"):
			closest_enemy.take_damage(damage, armor_piercing)
	
	# Remove the target marker
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.queue_free()
	
	# Destroy the projectile
	queue_free()


func _deal_splash_damage(impact_position: Vector2) -> void:
	"""Deal splash damage to all enemies within splash_radius."""
	if enemy_container == null:
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


## Initialize the artillery projectile
func setup(target_pos: Vector2, targets: Node2D, dmg: int, radius: float, pierce: bool = false, fired_by_enemy_unit: bool = false) -> void:
	target_position = target_pos
	enemy_container = targets
	damage = dmg
	splash_radius = radius
	armor_piercing = pierce
	fired_by_enemy = fired_by_enemy_unit
	
	# Position at target X, but off-screen above (will be set by spawner)
	position.x = target_pos.x
