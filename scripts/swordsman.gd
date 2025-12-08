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
	# Check if target is still valid and alive
	if target == null or not is_instance_valid(target):
		return
	
	if not target.has_method("take_damage"):
		return
	
	# Check if target is still alive (don't damage dead/dying units)
	if target is Unit:
		var target_unit := target as Unit
		if target_unit.current_hp <= 0 or target_unit.state == "dying":
			return
	
	# Don't deal damage if combat/battle has ended
	if not _is_combat_active():
		return
	
	# All checks passed - deal damage and play sound
	target.take_damage(damage, armor_piercing)
	_play_damage_sound()
