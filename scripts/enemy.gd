extends Unit
class_name Enemy

## Enemy - melee unit that fights for the enemy team.
## Uses default Unit behavior - no overrides needed.

func _ready() -> void:
	# Enemies are always on the enemy team
	is_enemy = true
	
	# Set default stats for enemy (can be overridden in inspector)
	if max_hp == 3:
		max_hp = 3
	if attack_range == 50.0:
		attack_range = 50.0
	if attack_cooldown == 1.0:
		attack_cooldown = 1.0
	
	super._ready()

