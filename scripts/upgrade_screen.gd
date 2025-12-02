extends Control
class_name UpgradeScreen

# Signals
signal continue_pressed(victory: bool)

# Node references (assign in inspector)
@export var your_army_tray: GridContainer
@export var enemies_faced_tray: GridContainer
@export var continue_button: Button

# Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

# State
var current_victory_state: bool = false


func _ready() -> void:
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	
	# Hide editor background at runtime
	hide_editor_background()
	
	# Ensure screen is hidden initially
	visible = false


func hide_editor_background() -> void:
	"""Hide the editor-only background at runtime."""
	if editor_background:
		editor_background.visible = false


func show_upgrade_screen(victory: bool, player_army: Array, enemies_faced: Array) -> void:
	"""Show the upgrade screen with army and enemy data."""
	current_victory_state = victory
	
	# Populate trays
	_populate_display_tray(your_army_tray, player_army)
	_populate_display_tray(enemies_faced_tray, enemies_faced)
	
	# Show upgrade screen
	visible = true


func hide_upgrade_screen() -> void:
	"""Hide the upgrade screen."""
	visible = false


func _populate_display_tray(tray: GridContainer, units: Array) -> void:
	"""Populate a display-only tray with unit textures."""
	if not tray:
		return
	
	var slots: Array[Control] = []
	for child in tray.get_children():
		if child is Control:
			slots.append(child)
	
	for i in range(slots.size()):
		var slot := slots[i] as Control
		if not slot:
			continue
		
		if i < units.size():
			var unit_data = units[i]
			var texture: Texture2D = null
			
			# unit_data can be ArmyUnit (from Game.army) or a Dictionary (from enemies_faced)
			var scene: PackedScene = null
			if unit_data is Dictionary:
				# Dictionary from enemies_faced
				if "unit_scene" in unit_data:
					scene = unit_data.unit_scene
			else:
				# ArmyUnit object - access property directly
				scene = unit_data.unit_scene
			
			if scene:
				texture = _get_texture_from_scene(scene)
			
			if slot.has_method("set_unit_texture"):
				slot.set_unit_texture(texture)
		else:
			# Clear unused slots
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


func _on_continue_button_pressed() -> void:
	"""Handle continue button press on upgrade screen."""
	hide_upgrade_screen()
	continue_pressed.emit(current_victory_state)
