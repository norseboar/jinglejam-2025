extends Control
class_name UnitSummary

@export var unit_sprite: TextureRect  # Existing TextureRect node in the scene
@export var unit_name_label: Label
@export var unit_description_label: Label
@export var stat_display_scene: PackedScene  # Assign scenes/ui/stat_display.tscn
@export var stats_grid: GridContainer  # GridContainer for stat displays (set columns to 4)
@export var upgrade_fraction_label: Label

@export_group("Stat Icons")
@export var count_icon: Texture2D
@export var hp_icon: Texture2D
@export var dmg_icon: Texture2D
@export var heal_icon: Texture2D
@export var atk_spd_icon: Texture2D
@export var def_icon: Texture2D
@export var spd_icon: Texture2D
@export var rng_icon: Texture2D

# Cached unit data for stat updates
var current_unit_scene: PackedScene = null

# Map stat names to icon textures
var stat_icons: Dictionary = {}


func _ready() -> void:
	"""Populate stat icons dictionary from exported textures."""
	stat_icons["count"] = count_icon
	stat_icons["hp"] = hp_icon
	stat_icons["dmg"] = dmg_icon
	stat_icons["heal"] = heal_icon
	stat_icons["atk_spd"] = atk_spd_icon
	stat_icons["def"] = def_icon
	stat_icons["spd"] = spd_icon
	stat_icons["rng"] = rng_icon


func _clear_stat_rows() -> void:
	"""Clear all stat displays from the grid."""
	if stats_grid:
		for child in stats_grid.get_children():
			child.queue_free()


func _add_stat_display(icon_key: String, value: int) -> void:
	"""Add a stat display to the grid."""
	if stat_display_scene == null:
		push_warning("stat_display_scene is not assigned!")
		return
	if stats_grid == null:
		push_warning("stats_grid is not assigned!")
		return
	
	var stat_display := stat_display_scene.instantiate()
	stats_grid.add_child(stat_display)
	
	# Set the stat using the StatDisplay script
	if stat_display.has_method("set_stat"):
		if not stat_icons.has(icon_key):
			push_warning("No icon texture assigned for stat: " + icon_key)
		elif stat_icons[icon_key] == null:
			push_warning("Icon texture is null for stat: " + icon_key)
		else:
			stat_display.set_stat(stat_icons[icon_key], value)
	else:
		push_warning("stat_display_scene doesn't have set_stat method! Make sure the StatDisplay script is attached.")


func _populate_stats(stats_data: Array) -> void:
	"""Populate stat displays from an array of stat data.
	stats_data format: [{icon: String, value: int}, ...]
	GridContainer automatically handles layout based on columns setting.
	"""
	_clear_stat_rows()
	
	# Add each stat to the grid (GridContainer handles row wrapping)
	for i in range(stats_data.size()):
		var stat: Dictionary = stats_data[i]
		_add_stat_display(stat.icon, stat.value)


func show_placeholder(text: String) -> void:
	"""Show placeholder text when no unit is selected."""
	if unit_sprite:
		unit_sprite.texture = null
	if unit_name_label:
		unit_name_label.text = text
	if unit_description_label:
		unit_description_label.text = ""
	_clear_stat_rows()
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
		
		# Build stats array and populate displays
		var stats_data := []
		var squad_size: int = unit.squad_count
		if is_healer:
			var heal: int = unit.heal_amount + stat_bonuses.heal_amount
			stats_data = [
				{icon = "count", value = squad_size},
				{icon = "hp", value = hp},
				{icon = "heal", value = heal},
				{icon = "atk_spd", value = atk_spd},
				{icon = "def", value = def},
				{icon = "spd", value = spd},
				{icon = "rng", value = rng}
			]
		else:
			var dmg: int = unit.damage + stat_bonuses.damage
			stats_data = [
				{icon = "count", value = squad_size},
				{icon = "hp", value = hp},
				{icon = "dmg", value = dmg},
				{icon = "atk_spd", value = atk_spd},
				{icon = "def", value = def},
				{icon = "spd", value = spd},
				{icon = "rng", value = rng}
			]
		
		_populate_stats(stats_data)

		# Calculate and display upgrade fraction
		var total_upgrades: int = 0
		for upgrade_count in upgrades.values():
			total_upgrades += upgrade_count as int
		if upgrade_fraction_label:
			upgrade_fraction_label.text = "%d/3 upgrades" % total_upgrades
	else:
		# Fallback if not a Unit
		if unit_name_label:
			unit_name_label.text = "Unknown"
		if unit_description_label:
			unit_description_label.text = ""
		_clear_stat_rows()
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
		
		# Build stats array and populate displays
		var stats_data := []
		var squad_size: int = unit.squad_count
		if is_healer:
			var heal: int = unit.heal_amount + stat_bonuses.heal_amount
			stats_data = [
				{icon = "count", value = squad_size},
				{icon = "hp", value = hp},
				{icon = "heal", value = heal},
				{icon = "atk_spd", value = atk_spd},
				{icon = "def", value = def},
				{icon = "spd", value = spd},
				{icon = "rng", value = rng}
			]
		else:
			var dmg: int = unit.damage + stat_bonuses.damage
			stats_data = [
				{icon = "count", value = squad_size},
				{icon = "hp", value = hp},
				{icon = "dmg", value = dmg},
				{icon = "atk_spd", value = atk_spd},
				{icon = "def", value = def},
				{icon = "spd", value = spd},
				{icon = "rng", value = rng}
			]
		
		_populate_stats(stats_data)

		# Update upgrade fraction
		var total_upgrades: int = 0
		for upgrade_count in upgrades.values():
			total_upgrades += upgrade_count as int
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
