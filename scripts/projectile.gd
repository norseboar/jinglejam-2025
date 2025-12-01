extends Node2D
class_name Projectile

## Projectile fired by ranged units. Moves in a direction until it hits an enemy or leaves the screen.

@export var speed := 400.0
@export var damage := 1
@export var hit_radius := 20.0  # How close to an enemy to count as a hit

var direction := Vector2.RIGHT
var enemy_container: Node2D = null  # Container of valid targets

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
		
		# Skip dead or dying units
		if enemy is Unit:
			if enemy.current_hp <= 0 or enemy.state == "dying":
				continue
		
		var distance := position.distance_to(enemy.position)
		if distance < hit_radius:
			# Hit! Deal damage and destroy projectile
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			queue_free()
			return


## Initialize the projectile with direction and target container
func setup(dir: Vector2, targets: Node2D, dmg: int) -> void:
	direction = dir.normalized()
	enemy_container = targets
	damage = dmg
	
	# Rotate sprite to face direction
	rotation = direction.angle()
