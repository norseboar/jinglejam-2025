extends Control

const GAME_SCENE = preload("res://scenes/game.tscn")

@export var start_button: TextureButton
@export var quit_button: TextureButton

func _ready() -> void:
	# Use default paths if not assigned in inspector
	if not start_button:
		start_button = $"bottom screen shit/Container/HBoxContainer/play"
	if not quit_button:
		quit_button = $"bottom screen shit/Container/HBoxContainer/exit"
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Play title music
	MusicManager.play_track(MusicManager.title_music)

func _on_start_pressed() -> void:
	# Defer the scene change to allow the button to visually release first
	call_deferred("_load_game_scene")

func _load_game_scene() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
