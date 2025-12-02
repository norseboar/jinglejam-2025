extends Control
class_name LevelRoot

## The background texture for this level (applied to Game's BackgroundRect at runtime)
@export var background_texture: Texture2D

## Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

func _ready() -> void:
	# Hide the editor-only background at runtime
	if editor_background:
		editor_background.visible = false
