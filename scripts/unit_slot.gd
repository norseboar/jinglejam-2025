extends Control
class_name UnitSlot

# Selection mode enum (mirrors UnitSlotGroup)
enum SelectionMode {
	NONE,   # No selection
	CLICK,  # Select on click
	HOVER   # Select on hover
}

# Signals
signal unit_slot_hovered(slot: UnitSlot)  # Pass the slot so parent knows which one
signal unit_slot_clicked(slot: UnitSlot)  # Pass the slot so parent knows which one

# Node references (assign in inspector)
@export var animated_sprite: AnimatedSprite2D
@export var selection_node: Control  # Generic Control for selection visuals
@export var background_node: Control  # Background Control node (e.g., Panel)

# Configuration
@export var enable_drag_drop: bool = false  # Enable drag-and-drop support
@export var selection_mode: SelectionMode = SelectionMode.CLICK  # How this slot is selected
@export var show_background: bool = true  # Whether to show the background node
@export var drag_preview_scene: PackedScene  # Custom scene for drag preview (optional - falls back to simple preview if not set)

# State
var is_selected: bool = false
var slot_index: int = -1  # Set by parent when populating
var current_army_unit: ArmyUnit = null

func _ready() -> void:
	# Ensure selection node is hidden initially
	if selection_node:
		selection_node.visible = false
	
	# Set background visibility based on show_background setting
	if background_node:
		background_node.visible = show_background
	
	# Connect UnitSlot's own mouse signals for hover detection
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func set_unit(army_unit: ArmyUnit) -> void:
	"""Set the unit to display from an ArmyUnit."""
	current_army_unit = army_unit
	
	if not army_unit or not army_unit.unit_scene:
		# Clear the slot
		if animated_sprite:
			animated_sprite.sprite_frames = null
			animated_sprite.stop()
		return
	
	# Extract SpriteFrames from the unit scene
	var sprite_frames: SpriteFrames = _extract_sprite_frames(army_unit.unit_scene)
	if sprite_frames and animated_sprite:
		animated_sprite.sprite_frames = sprite_frames
		# Don't play animation yet - will be controlled by selection state
		_update_animation_state()

func _update_animation_state() -> void:
	"""Update animation based on selection state - animate when selected, static frame when not."""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	if is_selected:
		# Animate when selected
		if not animated_sprite.is_playing():
			animated_sprite.play("idle")
	else:
		# Show first frame as static when not selected
		animated_sprite.stop()
		var anim_name := "idle" if animated_sprite.sprite_frames.has_animation("idle") else "default"
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.frame = 0
			animated_sprite.animation = anim_name

func _extract_sprite_frames(unit_scene: PackedScene) -> SpriteFrames:
	"""Extract SpriteFrames resource from a unit scene."""
	if not unit_scene:
		return null
	
	var instance := unit_scene.instantiate()
	var sprite_frames: SpriteFrames = null
	
	# Look for AnimatedSprite2D (assumes unit scenes have AnimatedSprite2D)
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	
	if sprite:
		sprite_frames = sprite.sprite_frames
	
	instance.queue_free()
	return sprite_frames

func set_selected(selected: bool) -> void:
	"""Show or hide the selection indicator."""
	is_selected = selected
	if selection_node:
		selection_node.visible = selected
	
	# Update animation state based on selection
	_update_animation_state()

func _on_mouse_entered() -> void:
	"""Handle mouse enter - emit hover signal and select if selection mode is HOVER."""
	unit_slot_hovered.emit(self)
	
	# Select on hover when selection mode is HOVER
	# Only select if slot has a unit
	if selection_mode == SelectionMode.HOVER and current_army_unit:
		set_selected(true)


func _on_mouse_exited() -> void:
	"""Handle mouse exit - unselect if selection mode is HOVER."""
	# Unselect on hover exit when selection mode is HOVER
	if selection_mode == SelectionMode.HOVER:
		set_selected(false)


func _gui_input(event: InputEvent) -> void:
	"""Handle mouse click events - emit signal for parent to handle selection when mode is CLICK."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			unit_slot_clicked.emit(self)
			accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Handle drag-and-drop when enabled."""
	if not enable_drag_drop:
		return null
	
	if not current_army_unit or slot_index < 0:
		return null
	
	# Find HUD by traversing up the tree (for phase check)
	var hud: HUD = null
	var current := get_parent()
	while current:
		if current is HUD:
			hud = current as HUD
			break
		current = current.get_parent()
	
	if not hud:
		return null
	
	# Check if we're in preparation phase
	if hud.current_phase != "preparation":
		return null
	
	# Create drag preview - use custom scene if provided, otherwise fallback to simple preview
	var preview: Control = null
	
	if drag_preview_scene:
		# Use custom drag preview scene (assumes it has an AnimatedSprite2D child)
		preview = drag_preview_scene.instantiate() as Control
		if preview:
			# Find AnimatedSprite2D child (assumes it exists)
			var preview_sprite: AnimatedSprite2D = preview.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if preview_sprite and animated_sprite and animated_sprite.sprite_frames:
				preview_sprite.sprite_frames = animated_sprite.sprite_frames
				preview_sprite.play("idle")
	else:
		# Fallback to colored rectangle if no texture
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview
	
	set_drag_preview(preview)
	
	return {
		"army_unit": current_army_unit,
		"army_index": slot_index
	}
