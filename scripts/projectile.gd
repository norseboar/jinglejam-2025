extends Node2D
class_name Projectile

## Projectile fired by ranged units. Moves in a direction until it hits an enemy or leaves the screen.

var speed := 400.0  # Set by unit that creates this projectile
var damage := 1  # Set by unit that creates this projectile
@export var hit_radius := 20.0  # How close to an enemy to count as a hit

var direction := Vector2.RIGHT
var enemy_container: Node2D = null  # Container of valid targets
var armor_piercing := false  # Set by unit that creates this projectile

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
			if enemy.current_hp <= 0 or enemy.state == "dying":
				continue
		
		var distance := position.distance_to(enemy.position)
		if distance < hit_radius:
			# Hit! Deal damage and destroy projectile
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, armor_piercing)
			queue_free()
			return


## Initialize the projectile with direction and target container
func setup(dir: Vector2, targets: Node2D, dmg: int, pierce: bool = false) -> void:
	direction = dir.normalized()
	enemy_container = targets
	damage = dmg
	armor_piercing = pierce
	
	# Rotate sprite to face direction
	rotation = direction.angle()
