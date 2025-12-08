extends Node2D
class_name DamageNumber

## Floating damage number that appears when a unit takes damage

@export var float_distance: float = 30.0  # How far up it floats in pixels
@export var float_duration: float = 0.8  # How long the animation takes in seconds
@export var random_horizontal_range: float = 15.0  # Random X offset range (±pixels)

# Number colors (configurable in inspector)
@export var damage_color: Color = Color(0.9, 0.2, 0.2)  # Red for damage
@export var heal_color: Color = Color(0.2, 0.9, 0.2)  # Green for healing
@export var shield_color: Color = Color(0.2, 0.7, 0.9)  # Cyan for shield/armor

var damage_amount: int = 0  # Set before adding to scene tree
var number_type: String = "damage"  # "damage", "heal", or "shield"

@onready var label: Label = $Label


func setup(amount: int, type: String = "damage") -> void:
	"""Set the amount and type to display. Call this before adding to scene tree."""
	damage_amount = amount
	number_type = type


func _ready() -> void:
	"""Start the float animation."""
	# Setup the label with damage amount and color based on type
	# For heal and shield, always show positive numbers
	var display_amount := damage_amount
	if number_type == "heal" or number_type == "shield":
		display_amount = abs(damage_amount)
	
	label.text = str(display_amount)
	
	# Choose color based on number type
	var display_color: Color
	match number_type:
		"heal":
			display_color = heal_color
		"shield":
			display_color = shield_color
		_:  # "damage" or default
			display_color = damage_color
	
	# Set the font color directly via theme override (more reliable than modulate)
	label.add_theme_color_override("font_color", display_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)  # Keep outline black for readability
	# Also set modulate to white to ensure no color multiplication issues
	label.modulate = Color.WHITE
	
	# Calculate random horizontal offset
	var random_x := randf_range(-random_horizontal_range, random_horizontal_range)
	var start_position := global_position
	var target_position := start_position + Vector2(random_x, -float_distance)

	# Create tween for animation
	var tween := create_tween()
	tween.set_parallel(true)  # Run both animations simultaneously

	# Animate global_position (float up with random horizontal drift)
	# Use TRANS_CUBIC with EASE_OUT for a smooth slowdown effect
	tween.tween_property(self, "global_position", target_position, float_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Animate fade out - start fading halfway through, fade slowly
	var fade_start_time := float_duration * 0.3  # Start fading at 30% of duration
	var fade_duration := float_duration - fade_start_time  # Fade over remaining 70%
	tween.tween_property(label, "modulate:a", 0.0, fade_duration).set_delay(fade_start_time).set_ease(Tween.EASE_OUT)

	# Cleanup when animation completes
	tween.finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	"""Destroy the damage number when animation completes."""
	queue_free()
