extends Node2D
class_name ImpactAnimation

## Animation scene that plays once and removes itself when finished.
## Attach this script to impact animation scenes.

var animated_sprite: AnimatedSprite2D = null


func _ready() -> void:
	# Find AnimatedSprite2D starting from this node (could be root or child)
	animated_sprite = _find_animated_sprite(self)
	
	if animated_sprite == null:
		push_error("ImpactAnimation: No AnimatedSprite2D found! Animation will not auto-remove.")
		return
	
	# Connect to animation finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Play the animation (AnimatedSprite2D will use its default animation or first sprite frames)
	animated_sprite.play()


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	"""Recursively find AnimatedSprite2D in the scene tree."""
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	
	for child in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	
	return null


func _on_animation_finished() -> void:
	"""Called when animation finishes - remove this node."""
	queue_free()
