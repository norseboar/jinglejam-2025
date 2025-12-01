extends Unit
class_name Swordsman

## Swordsman - melee unit that attacks enemies up close.
## Uses default Unit behavior - no overrides needed.

func _ready() -> void:
	# Set default stats for swordsman (can be overridden in inspector)
	if max_hp == 3:  # Only set if using default
		max_hp = 3
	if attack_range == 50.0:
		attack_range = 50.0
	if attack_cooldown == 1.0:
		attack_cooldown = 1.0
	
	super._ready()
