extends Unit
class_name Archer

## Archer - ranged unit that fires projectiles at enemies from a distance.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0


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


## Override to spawn a projectile instead of dealing direct damage
func _apply_attack_damage() -> void:
	if target == null or not is_instance_valid(target):
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
	
	# Setup projectile
	projectile.setup(direction, enemy_container, damage)
	projectile.speed = projectile_speed
