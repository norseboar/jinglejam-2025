extends Node2D
class_name DamageNumber

## Floating damage number that appears when a unit takes damage

@export var color: Color = Color(0.9, 0.2, 0.2)  # Default red shade
@export var float_distance: float = 30.0  # How far up it floats in pixels
@export var float_duration: float = 0.8  # How long the animation takes in seconds
@export var random_horizontal_range: float = 15.0  # Random X offset range (±pixels)

var damage_amount: int = 0  # Set before adding to scene tree

@onready var label: Label = $Label


func setup(amount: int) -> void:
	"""Set the damage amount to display. Call this before adding to scene tree."""
	damage_amount = amount


func _ready() -> void:
	"""Start the float animation."""
	# Setup the label with damage amount
	label.text = str(damage_amount)
	label.modulate = color
	
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
