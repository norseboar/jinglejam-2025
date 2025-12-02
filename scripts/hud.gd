extends Control
class_name HUD

# Signals
signal start_battle_requested
signal unit_drag_started(unit_type: String)
signal upgrade_confirmed(victory: bool)

# Node references
@onready var phase_label: Label = $PhaseLabel
@onready var tray_panel: Panel = $TrayPanel
@onready var unit_tray: GridContainer = $TrayPanel/UnitTray
@onready var go_button: Button = $TrayPanel/GoButton
@onready var upgrade_modal: ColorRect = $UpgradeModal
@onready var upgrade_label: Label = $UpgradeModal/Panel/VBoxContainer/UpgradeLabel
@onready var upgrade_confirm_button: Button = $UpgradeModal/Panel/VBoxContainer/UpgradeConfirmButton

# State
var current_phase: String = ""
var current_level: int = 0
var tray_slots: Array[Control] = []
var unit_definitions: Array[Dictionary] = []  # Array of {type: String, texture: Texture2D}

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
				# Make slots draggable by setting mouse filter
				child.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse events to pass through to children


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


func set_tray_units(unit_defs: Array) -> void:
	# unit_defs should be an array of dictionaries: [{type: "swordsman", texture: Texture2D}, ...]
	unit_definitions = unit_defs
	
	if not unit_tray:
		return
	
	# Clear existing children (except the slot Controls themselves)
	for i in range(tray_slots.size()):
		var slot := tray_slots[i] as Control
		if not slot:
			continue
		
		# Remove any existing icon children
		for child in slot.get_children():
			child.queue_free()
		
		# Add icon if we have a unit definition for this slot
		if i < unit_defs.size():
			var unit_def := unit_defs[i] as Dictionary
			var unit_type: String = unit_def.get("type", "")
			var unit_texture: Texture2D = unit_def.get("texture", null)
			
			if unit_texture:
				# Create a TextureRect for the icon
				var icon := TextureRect.new()
				icon.texture = unit_texture
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(32, 32)
				icon.mouse_filter = Control.MOUSE_FILTER_STOP
				
				# Store unit type as metadata
				icon.set_meta("unit_type", unit_type)
				
				slot.add_child(icon)
				
				# Make the slot handle drag (we'll override _get_drag_data on slot)
				# For now, connect mouse input to handle drag start
				if not slot.gui_input.is_connected(_on_slot_gui_input):
					slot.gui_input.connect(_on_slot_gui_input.bind(slot))


func show_upgrade_modal(victory: bool, level: int) -> void:
	if not upgrade_modal or not upgrade_label or not upgrade_confirm_button:
		return
	
	# Configure modal text
	if victory:
		if level >= 3:
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
	# Determine victory state from modal text or store it
	var victory := current_phase == "upgrade" and upgrade_label.text.contains("Victory")
	upgrade_modal.visible = false
	upgrade_confirmed.emit(victory)


func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	# Handle drag start from slot
	# Check if this slot has an icon and mouse is pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Find icon in this slot
			for child in slot.get_children():
				if child is TextureRect:
					var unit_type: String = child.get_meta("unit_type", "")
					if unit_type != "":
						# Emit signal
						unit_drag_started.emit(unit_type)
						break


func _create_drag_preview(icon: Control) -> Control:
	# Create a preview Control for dragging
	var preview := TextureRect.new()
	if icon is TextureRect:
		var source_icon := icon as TextureRect
		preview.texture = source_icon.texture
		preview.custom_minimum_size = Vector2(32, 32)
		preview.modulate = Color(1, 1, 1, 0.7)
	return preview
