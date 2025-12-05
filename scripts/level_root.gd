extends Control
class_name LevelRoot

## The background texture for this level (applied to Game's BackgroundRect at runtime)
@export var background_texture: Texture2D

## Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

## The name of the enemy army for this level (shown in battle select screen)
@export var army_name: String = "Enemy Army"

## Container node holding EnemySpawnSlot markers (optional - if not set, will search entire scene)
@export var enemy_spawn_slots_container: Node2D

func _ready() -> void:
	hide_editor_background()


func hide_editor_background() -> void:
	# Hide the editor-only background at runtime
	if editor_background:
		editor_background.visible = false
