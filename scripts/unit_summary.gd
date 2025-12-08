extends Control
class_name UnitSummary

@export var unit_sprite: TextureRect
@export var unit_name_label: Label
@export var unit_description_label: Label
@export var stats_label: Label
@export var upgrade_fraction_label: Label

# Cached unit data for stat updates
var current_unit_scene: PackedScene = null


func show_placeholder(text: String) -> void:
	"""Show placeholder text when no unit is selected."""
	if unit_sprite:
		unit_sprite.texture = null
	if unit_name_label:
		unit_name_label.text = text
	if unit_description_label:
		unit_description_label.text = ""
	if stats_label:
		stats_label.text = ""
	if upgrade_fraction_label:
		upgrade_fraction_label.text = ""


func show_unit_from_scene(unit_scene: PackedScene, upgrades: Dictionary = {}) -> void:
	"""Display unit info by instantiating the scene to read its properties."""
	if unit_scene == null:
		show_placeholder("No unit")
		return

	current_unit_scene = unit_scene

	# Instantiate to read properties
	var instance := unit_scene.instantiate()

	# Get texture from AnimatedSprite2D
	var texture: Texture2D = null
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")

	if sprite and sprite.sprite_frames:
		var anim_name := "idle" if sprite.sprite_frames.has_animation("idle") else "default"
		if sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			texture = sprite.sprite_frames.get_frame_texture(anim_name, 0)

	if unit_sprite:
		unit_sprite.texture = texture

	# Get display info (if Unit script is attached)
	if instance is Unit:
		var unit := instance as Unit

		if unit_name_label:
			unit_name_label.text = unit.display_name

		if unit_description_label:
			unit_description_label.text = unit.description

		# Calculate stats with upgrades applied
		var stat_bonuses := _calculate_stat_bonuses(unit, upgrades)
		var hp: int = unit.max_hp + stat_bonuses.max_hp
		var atk_spd: int = unit.attack_speed + stat_bonuses.attack_speed
		var def: int = unit.armor + stat_bonuses.armor
		var spd: int = int(unit.speed + stat_bonuses.speed)
		var rng: int = int(unit.attack_range + stat_bonuses.attack_range)
		
		# Check if unit is a healer
		var is_healer := unit is Healer
		
		if stats_label:
			if is_healer:
				var heal: int = unit.heal_amount + stat_bonuses.heal_amount
				stats_label.text = "HP: %d  HEAL: %d  CAST SPD: %d\nDEF: %d   SPD: %d  RNG: %d" % [hp, heal, atk_spd, def, spd, rng]
			else:
				var dmg: int = unit.damage + stat_bonuses.damage
				stats_label.text = "HP: %d  DMG: %d  ATK SPD: %d\nDEF: %d   SPD: %d  RNG: %d" % [hp, dmg, atk_spd, def, spd, rng]

		# Calculate and display upgrade fraction
		var total_upgrades: int = 0
		for count in upgrades.values():
			total_upgrades += count as int
		if upgrade_fraction_label:
			upgrade_fraction_label.text = "%d/3 upgrades" % total_upgrades
	else:
		# Fallback if not a Unit
		if unit_name_label:
			unit_name_label.text = "Unknown"
		if unit_description_label:
			unit_description_label.text = ""
		if stats_label:
			stats_label.text = ""
		if upgrade_fraction_label:
			upgrade_fraction_label.text = ""

	instance.queue_free()


func update_stats(upgrades: Dictionary) -> void:
	"""Update just the stats display with new upgrade values."""
	if current_unit_scene == null:
		return

	# Re-instantiate to get base stats
	var instance := current_unit_scene.instantiate()

	if instance is Unit:
		var unit := instance as Unit
		
		# Calculate stats with upgrades applied
		var stat_bonuses := _calculate_stat_bonuses(unit, upgrades)
		var hp: int = unit.max_hp + stat_bonuses.max_hp
		var atk_spd: int = unit.attack_speed + stat_bonuses.attack_speed
		var def: int = unit.armor + stat_bonuses.armor
		var spd: int = int(unit.speed + stat_bonuses.speed)
		var rng: int = int(unit.attack_range + stat_bonuses.attack_range)
		
		# Check if unit is a healer
		var is_healer := unit is Healer
		
		if stats_label:
			if is_healer:
				var heal: int = unit.heal_amount + stat_bonuses.heal_amount
				stats_label.text = "HP: %d  HEAL: %d  CAST SPD: %d\nDEF: %d  SPD: %d  RNG: %d" % [hp, heal, atk_spd, def, spd, rng]
			else:
				var dmg: int = unit.damage + stat_bonuses.damage
				stats_label.text = "HP: %d  DMG: %d  ATK SPD: %d\nDEF: %d   SPD: %d  RNG: %d" % [hp, dmg, atk_spd, def, spd, rng]

		# Update upgrade fraction
		var total_upgrades: int = 0
		for count in upgrades.values():
			total_upgrades += count as int
		if upgrade_fraction_label:
			upgrade_fraction_label.text = "%d/3 upgrades" % total_upgrades

	instance.queue_free()


func _calculate_stat_bonuses(unit: Unit, upgrades: Dictionary) -> Dictionary:
	"""Calculate stat bonuses from upgrades dictionary (which uses slot indices as keys)."""
	var bonuses := {
		"max_hp": 0,
		"damage": 0,
		"speed": 0.0,
		"attack_range": 0.0,
		"attack_speed": 0,
		"armor": 0,
		"heal_amount": 0
	}
	
	# Iterate through upgrades (keys are slot indices: 0, 1, 2)
	for upgrade_index in upgrades:
		if not upgrade_index is int:
			continue
		
		var count: int = upgrades[upgrade_index] as int
		if count <= 0:
			continue
		
		# Get the upgrade definition from available_upgrades
		if upgrade_index < 0 or upgrade_index >= unit.available_upgrades.size():
			continue
		
		var upgrade: UnitUpgrade = unit.available_upgrades[upgrade_index]
		var total_amount := upgrade.amount * count
		
		# Apply based on stat type
		match upgrade.stat_type:
			UnitUpgrade.StatType.MAX_HP:
				bonuses.max_hp += total_amount
			UnitUpgrade.StatType.DAMAGE:
				bonuses.damage += total_amount
			UnitUpgrade.StatType.SPEED:
				bonuses.speed += total_amount
			UnitUpgrade.StatType.ATTACK_RANGE:
				bonuses.attack_range += total_amount
			UnitUpgrade.StatType.ATTACK_SPEED:
				bonuses.attack_speed += total_amount
			UnitUpgrade.StatType.ARMOR:
				bonuses.armor += total_amount
			UnitUpgrade.StatType.HEAL_AMOUNT:
				bonuses.heal_amount += total_amount
	
	return bonuses
