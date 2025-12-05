extends Unit
class_name ArtilleryUnit

## Artillery unit that fires indirect attacks - projectile goes up, lands on target with AOE damage.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0  # Fall speed of the projectile
@export var target_marker_scene: PackedScene
@export var hit_delay := 1.5  # Seconds between animation finish and projectile spawn
@export var aoe_radius := 100.0  # Radius of impact damage

# Stored target position for the artillery strike
var _artillery_target_position := Vector2.ZERO
var _current_target_marker: Node2D = null


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
	
	if projectile_scene == null:
		push_error("ArtilleryUnit has no projectile_scene assigned!")
		return
	
	# Store the target position at the moment of firing
	_artillery_target_position = target.global_position
	
	# Spawn target marker
	_spawn_target_marker()
	
	# Wait for hit_delay, then spawn the projectile
	get_tree().create_timer(hit_delay).timeout.connect(_spawn_artillery_projectile)


func _spawn_target_marker() -> void:
	if target_marker_scene == null:
		push_warning("ArtilleryUnit has no target_marker_scene assigned!")
		return
	
	_current_target_marker = target_marker_scene.instantiate()
	get_parent().add_child(_current_target_marker)
	_current_target_marker.global_position = _artillery_target_position


func _spawn_artillery_projectile() -> void:
	# Spawn projectile
	var projectile: ArtilleryProjectile = projectile_scene.instantiate() as ArtilleryProjectile
	if projectile == null:
		push_error("Failed to instantiate artillery projectile!")
		# Clean up marker if projectile fails
		if _current_target_marker != null and is_instance_valid(_current_target_marker):
			_current_target_marker.queue_free()
		return
	
	# Add to scene tree
	get_parent().add_child(projectile)
	
	# Position off-screen above the target
	# Get the viewport height and position above it
	var viewport_rect := get_viewport_rect()
	var spawn_y := viewport_rect.position.y - 50  # 50 pixels above top of screen
	projectile.global_position = Vector2(_artillery_target_position.x, spawn_y)
	
	# Setup projectile
	projectile.setup(_artillery_target_position, enemy_container, damage, aoe_radius, armor_piercing, is_enemy)
	projectile.speed = projectile_speed
	projectile.target_marker = _current_target_marker
	# Pass impact sound callback to projectile
	projectile.impact_sound_callback = _play_impact_sound
	
	# Clear our reference (projectile now owns the marker)
	_current_target_marker = null
