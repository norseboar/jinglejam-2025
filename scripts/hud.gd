extends Control
class_name HUD

# Signals
signal start_battle_requested
signal upgrade_confirmed(victory: bool)

# Node references (assign in inspector)
@export var phase_label: Label
@export var tray_panel: Panel
@export var unit_tray: GridContainer
@export var go_button: Button
@export var upgrade_modal: ColorRect
@export var upgrade_label: Label
@export var upgrade_confirm_button: Button

# State
var current_phase: String = ""
var current_level: int = 0
var tray_slots: Array[Control] = []
var placed_unit_count: int = 0
var max_units: int = 10
var last_victory_state: bool = false  # Store victory state for upgrade confirmation

func _ready() -> void:
	# Connect Go button
	if go_button:
		go_button.pressed.connect(_on_go_button_pressed)
	
	# Connect upgrade confirm button
	if upgrade_confirm_button:
		upgrade_confirm_button.pressed.connect(_on_upgrade_confirm_button_pressed)
	
	# Ensure modal is hidden initially
	if upgrade_modal:
		upgrade_modal.visible = false
	
	# Get all tray slot Controls and set them up for dragging
	if unit_tray:
		for child in unit_tray.get_children():
			if child is Control:
				tray_slots.append(child)
				child.set_meta("slot_index", tray_slots.size() - 1)


func set_phase(phase: String, level: int) -> void:
	current_phase = phase
	current_level = level
	
	if phase_label:
		var phase_text := ""
		match phase:
			"preparation":
				phase_text = "Level %d – Preparation Phase" % level
			"battle":
				phase_text = "Level %d – Battle Phase" % level
			"upgrade":
				phase_text = "Level %d – Upgrade Phase" % level
			_:
				phase_text = "Level %d – %s" % [level, phase.capitalize()]
		
		phase_label.text = phase_text
	
	# Enable/disable Go button based on phase
	if go_button:
		go_button.disabled = (phase != "preparation")


func set_tray_unit_scenes(unit_scenes: Array[PackedScene]) -> void:
	"""Populate the tray with unit scenes. Extracts sprite textures from units."""
	placed_unit_count = 0
	
	if not unit_tray:
		return
	
	# Set up each slot
	for i in range(tray_slots.size()):
		var slot := tray_slots[i] as Control
		if not slot:
			continue
		
		# Configure slot for this unit
		if i < unit_scenes.size():
			var unit_scene: PackedScene = unit_scenes[i]
			if unit_scene == null:
				continue
			
			# Extract unit type from scene path (e.g., "res://scenes/units/swordsman.tscn" -> "swordsman")
			var scene_path: String = unit_scene.resource_path
			var unit_type: String = scene_path.get_file().get_basename()
			# Store metadata for drag-and-drop on the slot itself
			slot.set_meta("unit_type", unit_type)
			slot.set_meta("slot_index", i)
			
			# Try to extract texture from the unit scene
			var texture: Texture2D = _get_texture_from_scene(unit_scene)
			if slot.has_method("set_unit_texture"):
				slot.set_unit_texture(texture)
		else:
			slot.set_meta("unit_type", "")
			if slot.has_method("set_unit_texture"):
				slot.set_unit_texture(null)


func set_tray_from_army(army_units: Array) -> void:
	"""Populate the tray from army slot data."""
	placed_unit_count = 0

	if not unit_tray:
		return

	for i in range(tray_slots.size()):
		var slot := tray_slots[i] as Control
		if not slot:
			continue

		if i < army_units.size():
			var army_unit = army_units[i]
			if army_unit.placed:
				# Slot already used, clear it
				slot.set_meta("unit_type", "")
				slot.set_meta("slot_index", i)
				if slot.has_method("set_unit_texture"):
					slot.set_unit_texture(null)
			else:
				# Slot available, populate it
				slot.set_meta("unit_type", army_unit.unit_type)
				slot.set_meta("slot_index", i)

				var texture: Texture2D = _get_texture_from_scene(army_unit.unit_scene)
				if slot.has_method("set_unit_texture"):
					slot.set_unit_texture(texture)
		else:
			slot.set_meta("unit_type", "")
			if slot.has_method("set_unit_texture"):
				slot.set_unit_texture(null)


func _get_texture_from_scene(scene: PackedScene) -> Texture2D:
	"""Extract the first frame texture from a unit scene's AnimatedSprite2D."""
	var instance := scene.instantiate()
	var texture: Texture2D = null
	
	# Look for AnimatedSprite2D
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")
	
	if sprite and sprite.sprite_frames:
		# Get the first frame of the "idle" animation, or default animation
		var anim_name := "idle" if sprite.sprite_frames.has_animation("idle") else "default"
		if sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			texture = sprite.sprite_frames.get_frame_texture(anim_name, 0)
	
	instance.queue_free()
	return texture


func show_upgrade_modal(victory: bool, level: int, total_levels: int) -> void:
	if not upgrade_modal or not upgrade_label or not upgrade_confirm_button:
		return
	
	# Store victory state for later use
	last_victory_state = victory
	
	# Configure modal text
	if victory:
		if level >= total_levels:
			upgrade_label.text = "Victory! You've completed all levels!"
		else:
			upgrade_label.text = "Victory! Proceeding to Level %d..." % (level + 1)
	else:
		upgrade_label.text = "Defeat! Try again?"
	
	# Show the modal
	upgrade_modal.visible = true


func _on_go_button_pressed() -> void:
	if current_phase == "preparation":
		start_battle_requested.emit()


func _on_upgrade_confirm_button_pressed() -> void:
	# Use stored victory state
	upgrade_modal.visible = false
	upgrade_confirmed.emit(last_victory_state)



func update_placed_count(count: int) -> void:
	placed_unit_count = count
	# Disable/enable slots when max units reached
	if placed_unit_count >= max_units:
		for slot in tray_slots:
			if slot:
				slot.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Gray out
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Disable interaction
	else:
		for slot in tray_slots:
			if slot:
				slot.modulate = Color(1, 1, 1, 1)  # Normal color
				slot.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable interaction


func clear_tray_slot(index: int) -> void:
	"""Clear a tray slot after its unit has been placed."""
	if index < 0 or index >= tray_slots.size():
		return

	var slot := tray_slots[index]
	slot.set_meta("unit_type", "")
	if slot.has_method("set_unit_texture"):
		slot.set_unit_texture(null)
