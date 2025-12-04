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
		var hp: int = unit.max_hp + upgrades.get("hp", 0) as int
		var dmg: int = unit.damage + upgrades.get("damage", 0) as int
		var spd := int(unit.speed / 10.0)
		var rng := int(unit.attack_range / 10.0)

		if stats_label:
			stats_label.text = "HP: %d  DMG: %d  SPD: %d  RNG: %d" % [hp, dmg, spd, rng]

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
		var hp: int = unit.max_hp + upgrades.get("hp", 0) as int
		var dmg: int = unit.damage + upgrades.get("damage", 0) as int
		var spd := int(unit.speed / 10.0)
		var rng := int(unit.attack_range / 10.0)

		if stats_label:
			stats_label.text = "HP: %d  DMG: %d  SPD: %d  RNG: %d" % [hp, dmg, spd, rng]

		# Update upgrade fraction
		var total_upgrades: int = 0
		for count in upgrades.values():
			total_upgrades += count as int
		if upgrade_fraction_label:
			upgrade_fraction_label.text = "%d/3 upgrades" % total_upgrades

	instance.queue_free()
