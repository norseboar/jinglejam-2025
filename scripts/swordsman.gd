extends Unit
class_name Swordsman

## Swordsman - melee unit that attacks enemies up close.
## Handles melee damage dealing on the attack damage frame.

func _ready() -> void:
	# Set default stats for swordsman (can be overridden in inspector)
	if max_hp == 3:  # Only set if using default
		max_hp = 3
	if attack_range == 50.0:
		attack_range = 50.0
	if attack_cooldown == 1.0:
		attack_cooldown = 1.0
	
	super._ready()


## Override to handle melee damage dealing on the attack frame
func _execute_attack() -> void:
	# Melee behavior - deal damage directly to target and play damage sound
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, armor_piercing)
		# Play damage sound when damage is applied
		_play_damage_sound()
