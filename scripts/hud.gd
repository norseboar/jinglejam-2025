extends Control
class_name HUD

# Signals
signal start_battle_requested
signal auto_deploy_requested  # Emitted when auto-deploy button is clicked
signal upgrade_confirmed(victory: bool)
signal show_upgrade_screen_requested  # Emitted when battle end button is clicked (victory)
signal battle_select_advance_data(option_data: BattleOptionData)  # Emits BattleOptionData
signal draft_complete()

# Node references (assign in inspector)
@export var phase_label: Label
@export var tray_panel: TrayPanel
@export var unit_tray: GridContainer
@export var go_button: BaseButton
@export var auto_deploy_button: BaseButton  # Auto-deploy button (add in editor next to Go button)
@export var gold_label: Label
@export var gold_container: Control
@export var battle_group: Control

# Battle end modal (shown first, then leads to upgrade screen)
@export var battle_end_modal: ColorRect
@export var battle_end_label: Label
@export var battle_end_button: BaseButton

# Upgrade screen reference (assign in inspector)
@export var upgrade_screen: UpgradeScreen
@export var battle_select_screen: BattleSelectScreen

# State
var current_phase: String = ""
var current_level: int = 0
var tray_slots: Array[Control] = []
var placed_unit_count: int = 0
var max_units: int = 10
var last_victory_state: bool = false  # Store victory state for upgrade screen
var is_last_level: bool = false  # Track if current battle was the last level

func _ready() -> void:
	# Connect Go button
	if go_button:
		go_button.pressed.connect(_on_go_button_pressed)
	
	# Connect auto-deploy button
	if auto_deploy_button:
		auto_deploy_button.pressed.connect(_on_auto_deploy_button_pressed)
	
	# Connect battle end button
	if battle_end_button:
		battle_end_button.pressed.connect(_on_battle_end_button_pressed)
	
	# Connect upgrade screen continue signal
	if upgrade_screen:
		upgrade_screen.continue_pressed.connect(_on_upgrade_screen_continue_pressed)
		upgrade_screen.draft_complete.connect(_on_draft_complete)
	
	# Connect battle select screen signals
	if battle_select_screen:
		battle_select_screen.advance_pressed.connect(_on_battle_select_advance_pressed_data)
	
	# Ensure modal is hidden initially
	if battle_end_modal:
		battle_end_modal.visible = false
	
	# Get all tray slot Controls and set them up
	if unit_tray:
		for child in unit_tray.get_children():
			if child is UnitSlot:
				tray_slots.append(child)
				var slot := child as UnitSlot
				slot.slot_index = tray_slots.size() - 1
	
	# Connect to Game's gold_changed signal
	var game := get_tree().get_first_node_in_group("game") as Game
	if game:
		game.gold_changed.connect(update_gold_display)
		# Initialize display with current gold
		update_gold_display(game.gold)


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
			"battle_end":
				phase_text = "Level %d – Battle End" % level
			"upgrade":
				phase_text = "Level %d – Upgrade Phase" % level
			_:
				phase_text = "Level %d – %s" % [level, phase.capitalize()]
		
		phase_label.text = phase_text
	
	# Enable/disable Go button based on phase and placed units
	if go_button:
		if phase == "preparation":
			go_button.disabled = (placed_unit_count == 0)
		else:
			go_button.disabled = true
	
	# Update auto-deploy button state
	_update_auto_deploy_button_state()
	
	# Update visibility/animations based on phase
	_update_phase_visibility()


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
	
	# Reset slot modulation to normal (in case they were grayed out from previous level)
	for slot in tray_slots:
		if slot:
			slot.modulate = Color(1, 1, 1, 1)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP

	if not unit_tray:
		return

	for i in range(tray_slots.size()):
		var slot = tray_slots[i]
		if not slot:
			continue

		if i < army_units.size():
			var army_unit = army_units[i]
			if army_unit.placed:
				# Slot already used, clear it
				if slot is UnitSlot:
					var unit_slot := slot as UnitSlot
					unit_slot.set_unit(null)
				else:
					# Fallback for old slots
					slot.set_meta("unit_type", "")
					slot.set_meta("slot_index", i)
					if slot.has_method("set_unit_texture"):
						slot.set_unit_texture(null)
			else:
				# Slot available, populate it
				if slot is UnitSlot:
					var unit_slot := slot as UnitSlot
					unit_slot.slot_index = i
					unit_slot.set_unit(army_unit)
				else:
					# Fallback for old slots
					slot.set_meta("unit_type", army_unit.unit_type)
					slot.set_meta("slot_index", i)
					var texture: Texture2D = _get_texture_from_scene(army_unit.unit_scene)
					if slot.has_method("set_unit_texture"):
						slot.set_unit_texture(texture)
		else:
			# Empty slot
			if slot is UnitSlot:
				var unit_slot := slot as UnitSlot
				unit_slot.set_unit(null)
			else:
				# Fallback for old slots
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


func show_battle_end_modal(victory: bool, level: int, total_levels: int) -> void:
	"""Show the battle end modal that leads to upgrade screen."""
	last_victory_state = victory
	is_last_level = (level >= total_levels)
	
	if not battle_end_modal or not battle_end_label or not battle_end_button:
		return
	
	# Configure modal text and button
	if victory:
		if is_last_level:
			# Last level completed - show victory message and restart option
			battle_end_label.text = "Victory! You've completed all levels!"
			if battle_end_button is Button:
				battle_end_button.text = "Restart"
		else:
			battle_end_label.text = "Victory!"
			if battle_end_button is Button:
				battle_end_button.text = "Upgrade Army"
	else:
		battle_end_label.text = "Defeat!"
		if battle_end_button is Button:
			battle_end_button.text = "Restart"
	
	# Show the modal
	battle_end_modal.visible = true


func show_upgrade_screen(victory: bool, player_army: Array, enemies_faced: Array) -> void:
	"""Show the upgrade screen with army and enemy data."""
	# Hide battle end modal
	if battle_end_modal:
		battle_end_modal.visible = false

	# Hide HUD elements (tray, phase label, etc.)
	hide_hud_elements()

	# Delegate to upgrade screen
	if upgrade_screen:
		upgrade_screen.show_upgrade_screen(victory, player_army, enemies_faced)


func show_draft_screen(roster: Roster) -> void:
	"""Show the upgrade screen in draft mode."""
	# Hide HUD elements (tray, phase label, etc.)
	hide_hud_elements()
	
	# Delegate to upgrade screen
	if upgrade_screen:
		upgrade_screen.show_draft_screen(roster)


func _on_go_button_pressed() -> void:
	if current_phase == "preparation":
		start_battle_requested.emit()


func _on_auto_deploy_button_pressed() -> void:
	"""Handle auto-deploy button press."""
	if current_phase == "preparation":
		auto_deploy_requested.emit()


func _update_auto_deploy_button_state() -> void:
	"""Update the auto-deploy button enabled/disabled state."""
	if not auto_deploy_button:
		return
	
	# Disable if battle is happening
	if current_phase == "battle":
		auto_deploy_button.disabled = true
		return
	
	# Disable if not in preparation phase
	if current_phase != "preparation":
		auto_deploy_button.disabled = true
		return
	
	# Check if there are any unplaced units by checking the Game's army
	var game := get_tree().get_first_node_in_group("game") as Game
	if not game:
		auto_deploy_button.disabled = true
		return
	
	var has_unplaced_units := false
	for army_unit in game.army:
		var unit: ArmyUnit = army_unit as ArmyUnit
		if unit and not unit.placed and unit.unit_scene != null:
			has_unplaced_units = true
			break
	
	# Enable if there are unplaced units, disable otherwise
	auto_deploy_button.disabled = not has_unplaced_units


func _on_battle_end_button_pressed() -> void:
	"""Handle battle end button - shows upgrade screen (or restarts if defeat or last level victory)."""
	# Hide modal
	if battle_end_modal:
		battle_end_modal.visible = false
	
	# If defeat, restart immediately
	if not last_victory_state:
		upgrade_confirmed.emit(false)
		return
	
	# If victory on last level, restart immediately (no upgrade screen)
	if is_last_level:
		upgrade_confirmed.emit(true)
		return
	
	# Otherwise, victory on non-last level - show upgrade screen
	# Signal to Game to show upgrade screen
	show_upgrade_screen_requested.emit()


func _on_upgrade_screen_continue_pressed(victory: bool) -> void:
	"""Handle continue signal from upgrade screen."""
	upgrade_confirmed.emit(victory)


func _on_draft_complete() -> void:
	"""Forward draft complete signal from upgrade screen."""
	# Hide upgrade screen (which reshows HUD elements)
	hide_upgrade_screen()
	# Forward signal to game
	draft_complete.emit()


func hide_upgrade_screen() -> void:
	"""Hide the upgrade screen."""
	if upgrade_screen:
		upgrade_screen.hide_upgrade_screen()
	
	# Re-show HUD elements
	show_hud_elements()


func show_battle_select(scenes: Array[PackedScene]) -> void:
	"""Show the battle select screen with level options."""
	if battle_select_screen:
		battle_select_screen.show_battle_select(scenes)


func show_battle_select_generated(data_list: Array) -> void:
	"""Show the battle select screen with generated battle options."""
	if battle_select_screen:
		# Get player's army from game
		var game := get_tree().get_first_node_in_group("game") as Game
		var player_army: Array = []
		if game:
			player_army = game.army
		
		battle_select_screen.show_battle_select_generated(data_list, player_army)


func hide_battle_select() -> void:
	"""Hide the battle select screen."""
	if battle_select_screen:
		battle_select_screen.hide_battle_select()


func hide_battle_section_for_faction_select() -> void:
	"""Hide battle UI while faction selection is shown."""
	if battle_group:
		battle_group.visible = false
	else:
		if tray_panel:
			if tray_panel is TrayPanel:
				(tray_panel as TrayPanel).hide_immediately()
			else:
				tray_panel.visible = false
		if phase_label:
			phase_label.get_parent().visible = false


func _on_battle_select_advance_pressed_data(option_data: BattleOptionData) -> void:
	"""Handle advance from battle select screen with generated data."""
	hide_battle_select()
	battle_select_advance_data.emit(option_data)


func hide_hud_elements() -> void:
	"""Hide HUD UI elements (tray, phase label, etc.) when upgrade screen is shown."""
	if battle_group:
		battle_group.visible = false
	else:
		if tray_panel:
			if tray_panel is TrayPanel:
				(tray_panel as TrayPanel).hide_immediately()
			else:
				tray_panel.visible = false
		if phase_label:
			phase_label.get_parent().visible = false  # Hide the PanelContainer parent of phase_label
	if gold_container:
		gold_container.visible = false


func show_hud_elements() -> void:
	"""Show HUD UI elements after upgrade screen is closed."""
	_update_phase_visibility()


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
	
	# Enable/disable Go button based on whether any units are placed
	if go_button:
		if current_phase == "preparation":
			go_button.disabled = (placed_unit_count == 0)
		else:
			go_button.disabled = true
	
	# Update auto-deploy button state
	_update_auto_deploy_button_state()


func clear_tray_slot(index: int) -> void:
	"""Clear a tray slot after its unit has been placed."""
	if index < 0 or index >= tray_slots.size():
		return

	var slot := tray_slots[index]
	if slot is UnitSlot:
		var unit_slot := slot as UnitSlot
		unit_slot.set_unit(null)
	else:
		# Fallback for old slots
		slot.set_meta("unit_type", "")
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(null)


func update_gold_display(amount: int) -> void:
	"""Update the gold label text."""
	if gold_label:
		gold_label.text = "Gold: %d" % amount


func _update_phase_visibility() -> void:
	"""Handle visibility/animation for HUD elements based on the current phase."""
	var is_battle_phase := current_phase == "battle" or current_phase == "battle_end"
	var is_battle_mode := current_phase == "preparation" or is_battle_phase
	
	if battle_group:
		battle_group.visible = is_battle_mode
	else:
		# Fallback to show/hide individual elements when no battle_group is provided
		if phase_label:
			phase_label.get_parent().visible = is_battle_mode
		if tray_panel and not is_battle_phase:
			tray_panel.visible = is_battle_mode
	
	if gold_container:
		gold_container.visible = is_battle_phase
	
	_update_tray_panel(is_battle_mode, is_battle_phase)


func _update_tray_panel(is_battle_mode: bool, is_battle_phase: bool) -> void:
	if not tray_panel:
		return
	
	if tray_panel is TrayPanel:
		var tray := tray_panel as TrayPanel
		
		if not is_battle_mode:
			tray.hide_immediately()
			return
		
		if is_battle_phase:
			tray.slide_out()
		else:
			tray.slide_in()
	else:
		# Fallback if tray_panel is not a TrayPanel script
		tray_panel.visible = is_battle_mode and not is_battle_phase


func get_gold_counter_position() -> Vector2:
	"""Get the global position of the gold counter (center of gold label)."""
	if gold_label == null:
		return Vector2.ZERO
	
	var pos := gold_label.global_position
	# Return center of the label
	return pos + Vector2(gold_label.size.x / 2, gold_label.size.y / 2)
