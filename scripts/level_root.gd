extends Node2D
class_name LevelRoot

## The background texture for this level (applied to Game's BackgroundRect at runtime)
@export var background_texture: Texture2D

@onready var editor_background: Sprite2D = $EditorBackground

func _ready() -> void:
	# Hide the editor-only background at runtime
	if editor_background:
		editor_background.visible = false

