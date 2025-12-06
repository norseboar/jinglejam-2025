extends Node2D
class_name CoinAnimation

## Coin animation that moves from a source position to the gold counter.
## Fades in quickly, moves to target, fades out, then plays sound and removes itself.

# Exposed parameters for fade timing
@export var fade_in_duration: float = 0.1  # How fast to fade in (opacity 0 to 1)
@export var fade_out_duration: float = 0.15  # How fast to fade out (opacity 1 to 0)
@export var move_duration: float = 0.6  # How long to take moving to gold counter
@export var coin_sounds: Array[AudioStream] = []  # List of coin sound effects to randomly choose from

var animated_sprite: AnimatedSprite2D = null
var audio_player: AudioStreamPlayer2D = null


func _ready() -> void:
	# Find AnimatedSprite2D
	animated_sprite = _find_animated_sprite(self)
	if animated_sprite == null:
		push_error("CoinAnimation: No AnimatedSprite2D found!")
		queue_free()
		return
	
	# Create audio player for coin sound
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Start with opacity 0
	modulate.a = 0.0


func animate_to_target(start_pos: Vector2, target_pos: Vector2) -> void:
	"""Start the coin animation from start_pos to target_pos."""
	if animated_sprite == null:
		return
	
	# Set starting position
	global_position = start_pos
	
	# Create tween for the entire animation
	var tween := create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Fade in (opacity 0 to 1)
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	
	# Move to target position
	tween.tween_property(self, "global_position", target_pos, move_duration)
	
	# Wait for movement to complete, then fade out
	await tween.finished
	
	# Fade out (opacity 1 to 0)
	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	
	# Play sound when reaching target (during fade out)
	_play_coin_sound()
	
	# Wait for fade out to complete, then remove
	await fade_out_tween.finished
	queue_free()


func _play_coin_sound() -> void:
	"""Play a random coin sound effect from the coin_sounds array."""
	if coin_sounds.is_empty() or audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % coin_sounds.size()
	var sound: AudioStream = coin_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	"""Recursively find AnimatedSprite2D in the scene tree."""
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	
	for child in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	
	return null

