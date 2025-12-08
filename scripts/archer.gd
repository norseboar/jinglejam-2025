extends Unit
class_name Archer

## Archer - ranged unit that fires projectiles at enemies from a distance.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0
@export var splash_radius := 0.0  # Radius for splash damage (0 = no splash, direct hit only)
@export var impact_animation_scene: PackedScene = null  # Optional scene to instantiate on impact
@export var projectile_use_target := false  # When true, send projectiles to a point instead of just a direction
@export var projectile_arc_amplitude := 0.0
@export var projectile_ignore_until_target := false
@export var projectile_force_aoe_only := false


func _ready() -> void:
	# Set default stats for archer (can be overridden in inspector)
	if max_hp == 3:
		max_hp = 2  # Archers are squishier
	if attack_range == 50.0:
		attack_range = 300.0  # Much longer range
	if attack_cooldown == 1.0:
		attack_cooldown = 1.5  # Slower attack
	if speed == 100.0:
		speed = 80.0  # Slower movement
	
	super._ready()


## Override to play fire sound and spawn projectile on attack frame
func _trigger_attack_damage() -> void:
	"""Play fire sound and spawn projectile on the attack frame."""
	has_triggered_frame_damage = true
	_play_fire_sound()
	_execute_attack()


## Override to spawn a projectile (damage happens when projectile hits)
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
		push_error("Archer has no projectile_scene assigned!")
		return
	
	# Spawn projectile
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_error("Failed to instantiate projectile!")
		return
	
	# Add to scene tree (add to parent so it's not a child of the archer)
	get_parent().add_child(projectile)
	
	# Position at archer's location
	projectile.global_position = global_position
	
	# Calculate direction to target
	var direction := (target.global_position - global_position).normalized()
	
	# Setup projectile with impact sound callback
	var target_pos := target.global_position
	projectile.setup(
		direction,
		enemy_container,
		damage,
		armor_piercing,
		is_enemy,
		projectile_use_target,
		target_pos,
		projectile_arc_amplitude,
		projectile_ignore_until_target,
		projectile_force_aoe_only
	)
	projectile.speed = projectile_speed
	projectile.splash_radius = splash_radius
	projectile.impact_animation_scene = impact_animation_scene
	# Pass impact sound callback to projectile
	projectile.impact_sound_callback = _play_impact_sound
