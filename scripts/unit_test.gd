extends Node2D

# Simple test scene for Unit behavior
# Spawns a player unit and an enemy unit, sets them up to fight

@export var unit_scene: PackedScene

var player_unit: Unit = null
var enemy_unit: Unit = null


func _ready() -> void:
	# Create containers
	var player_container := Node2D.new()
	player_container.name = "PlayerContainer"
	add_child(player_container)
	
	var enemy_container := Node2D.new()
	enemy_container.name = "EnemyContainer"
	add_child(enemy_container)
	
	# Spawn player unit on the left
	if unit_scene:
		player_unit = unit_scene.instantiate() as Unit
		if player_unit:
			player_unit.position = Vector2(200, 300)
			player_unit.is_enemy = false
			player_unit.enemy_container = enemy_container
			player_container.add_child(player_unit)
	
	# Spawn enemy unit on the right
	if unit_scene:
		enemy_unit = unit_scene.instantiate() as Unit
		if enemy_unit:
			enemy_unit.position = Vector2(600, 300)
			enemy_unit.is_enemy = true
			enemy_unit.enemy_container = player_container
			enemy_container.add_child(enemy_unit)
	
	# Start the battle after a short delay
	get_tree().create_timer(1.0).timeout.connect(_start_battle)


func _start_battle() -> void:
	if player_unit:
		player_unit.state = "moving"
	if enemy_unit:
		enemy_unit.state = "moving"
