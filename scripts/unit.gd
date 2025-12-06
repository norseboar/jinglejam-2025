extends Node2D
class_name Unit

# Signals
signal enemy_unit_died(gold_reward: int)  # Emitted by enemies with gold_reward
signal player_unit_died(army_index: int)  # Emitted by player units with army_index

# Stats
@export var max_hp := 3
@export var damage := 1
@export var speed := 100.0           # pixels per second
@export var attack_range := 50.0     # radius to attack enemies
@export var detection_range := 2000.0 # radius to detect enemies (very large to cover screen)
@export var attack_cooldown := 0.0   # seconds to wait in idle after attack animation completes (0 = no cooldown)
@export var attack_damage_frame := 0 # Frame number in attack animation when damage is dealt
@export var priority := 1            # Priority for targeting (higher = more important)
@export var armor := 0               # Damage reduction (subtracted from incoming damage)
@export var armor_piercing := false  # If true, attacks ignore enemy armor
@export var targets_high_priority := false  # If true, only targets highest priority enemies

# Display info
@export var display_name: String = "Unit"
@export var description: String = "A basic unit."

# Gold system properties
@export var base_recruit_cost := 10  # Base cost to recruit this unit type
@export var upgrade_cost := 5  # Cost per upgrade (HP or Damage)
@export var gold_reward := 5  # Gold given when this unit is killed

# Sound effects
@export var damage_sounds: Array[AudioStream] = [
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 1.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 2.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 3.wav"),
	preload("res://assets/sfx/sword_impact/Shield Impacts Sword 5.wav")
]  # List of damage sound effects to randomly choose from (for melee units)

@export var fire_sounds: Array[AudioStream] = []  # List of fire sound effects for ranged units (plays on attack frame)
@export var impact_sounds: Array[AudioStream] = []  # List of impact sound effects for ranged units (plays when projectile hits)

# State
var current_hp := 3
var is_enemy := false        # true = moves left (enemy), false = moves right (player)
var state := "idle"          # "idle" | "moving" | "fighting" | "dying"
var target: Node2D = null    # current attack target
var time_since_attack := 0.0 # timer for attack cooldown
var is_attacking := false    # true when attack animation is playing
var has_triggered_frame_damage := false  # Prevents multiple damage triggers per attack
var army_index := -1         # Index in Game.army array, or -1 if not from army

# Upgrades
var upgrades: Dictionary = {}  # e.g., { "hp": 2, "damage": 1 }

# Reference to the container holding enemies (set by Game.gd when spawning)
var enemy_container: Node2D = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	current_hp = max_hp
	# Flip sprite to face correct direction based on team
	# This must happen in _ready() so enemies face the correct direction immediately
	if animated_sprite:
		animated_sprite.flip_h = is_enemy
		_safe_play_animation("idle")
		# Connect to frame_changed signal to detect attack damage frame
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)


func _process(delta: float) -> void:
	match state:
		"idle":
			pass  # Do nothing, waiting for battle to start
		"moving":
			_do_movement(delta)
		"fighting":
			_do_fighting(delta)
		"dying":
			pass  # Do nothing, unit is fading out


func set_state(new_state: String) -> void:
	if state == new_state:
		return
	
	# Reset attacking flag if leaving fighting state
	if state == "fighting" and new_state != "fighting":
		is_attacking = false
	
	state = new_state
	match state:
		"idle":
			_safe_play_animation("idle")
		"moving":
			_safe_play_animation("walk")
		"fighting":
			pass  # Attack animation played per attack
		"dying":
			_safe_play_animation("idle")  # Play idle animation while dying


func _do_movement(delta: float) -> void:
	# Check for enemies first
	_check_for_targets()
	
	# If we have a target, move towards it
	if target != null and is_instance_valid(target):
		var target_pos := target.position
		var direction_to_target := (target_pos - position).normalized()
		
		# Move towards target
		position += direction_to_target * speed * delta
		
		# Flip sprite to face movement direction
		animated_sprite.flip_h = direction_to_target.x < 0
	else:
		# No target - move in default direction based on team
		var direction := 1.0 if not is_enemy else -1.0  # Player moves right, enemy moves left
		
		# Flip sprite to face movement direction
		animated_sprite.flip_h = is_enemy
		
		# Move horizontally
		position.x += direction * speed * delta


func _check_for_targets() -> void:
	if enemy_container == null:
		return

	var closest_enemy: Node2D = null
	var closest_distance := INF

	if targets_high_priority:
		# Priority-based targeting: find highest priority, then closest of those
		var highest_priority := -INF
		var high_priority_enemies: Array[Unit] = []
		
		# First pass: find highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			var distance := position.distance_to(enemy.position)
			if distance >= detection_range:
				continue
			
			if unit_enemy.priority > highest_priority:
				highest_priority = unit_enemy.priority
		
		# Second pass: collect all enemies with highest priority
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue
			
			var distance := position.distance_to(enemy.position)
			if distance >= detection_range:
				continue
			
			if unit_enemy.priority == highest_priority:
				high_priority_enemies.append(unit_enemy)
		
		# Third pass: find closest among high priority enemies
		for unit_enemy in high_priority_enemies:
			var distance := position.distance_to(unit_enemy.position)
			if distance < closest_distance:
				closest_enemy = unit_enemy
				closest_distance = distance
	else:
		# Normal targeting: just find closest enemy
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			# Only consider Unit nodes as valid targets
			if not enemy is Unit:
				continue
			
			var unit_enemy := enemy as Unit
			if unit_enemy.current_hp <= 0 or unit_enemy.state == "dying":
				continue  # Skip dead or dying units

			var distance := position.distance_to(enemy.position)
			
			# Check if enemy is within detection range
			if distance < detection_range and distance < closest_distance:
				closest_enemy = enemy
				closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		var distance_to_target := position.distance_to(closest_enemy.position)
		
		# If we're in attack range, start fighting
		if distance_to_target <= attack_range:
			set_state("fighting")
			# Reset cooldown timer when entering combat
			# Ranged units (not Swordsman) get a random delay for first attack to stagger them
			if self is Archer or self is ArtilleryUnit:
				# Random delay between 0 and attack_cooldown for first attack
				time_since_attack = randf() * attack_cooldown
			else:
				# Melee units (Swordsman) attack immediately
				time_since_attack = attack_cooldown  # Set to cooldown value so attack happens immediately
		# Otherwise, we'll keep moving towards them (state stays "moving")


func _do_fighting(delta: float) -> void:
	# Check if target is still valid and is a Unit
	if not is_instance_valid(target) or not target is Unit:
		target = null
		set_state("moving")
		return
	
	var target_unit := target as Unit
	if target_unit.current_hp <= 0 or target_unit.state == "dying":
		target = null
		set_state("moving")
		return

	# Check if target moved out of attack range
	var distance := position.distance_to(target.position)
	if distance > attack_range * 1.2:  # Small buffer to prevent flickering
		# Keep the target but switch to moving so we can move towards them
		set_state("moving")
		return

	# Attack immediately when not attacking, then wait for cooldown after attack completes
	if not is_attacking:
		# If no cooldown, or cooldown has passed since last attack finished, attack immediately
		if attack_cooldown <= 0.0 or time_since_attack >= attack_cooldown:
			_attack_target()
		else:
			# Count cooldown timer during idle (after attack animation completes)
			time_since_attack += delta


func _attack_target() -> void:
	if target == null or not is_instance_valid(target) or is_attacking:
		return

	# Set attacking flag and reset frame damage trigger
	is_attacking = true
	has_triggered_frame_damage = false
	
	# Play attack animation at normal speed (no scaling)
	animated_sprite.speed_scale = 1.0
	_safe_play_animation("attack")

	# Get animation duration at normal speed
	var anim_duration := _get_attack_animation_duration()
	
	if anim_duration > 0:
		get_tree().create_timer(anim_duration).timeout.connect(_on_attack_animation_finished)
	else:
		_on_attack_animation_finished()


func _get_attack_animation_duration() -> float:
	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation("attack"):
		return 0.0
	
	var frame_count := sprite_frames.get_frame_count("attack")
	var anim_speed := sprite_frames.get_animation_speed("attack")
	var anim_duration := 0.0
	
	for i in range(frame_count):
		var frame_duration_frames := sprite_frames.get_frame_duration("attack", i)
		var frame_duration_seconds := frame_duration_frames / anim_speed
		anim_duration += frame_duration_seconds
	
	return anim_duration


func _on_attack_animation_finished() -> void:
	"""Called when attack animation completes. Resets state and switches back to idle."""
	is_attacking = false
	
	# Switch back to idle animation
	# If attack_cooldown > 0, we'll wait in idle for that duration before next attack
	if state == "fighting" and animated_sprite:
		_safe_play_animation("idle")
		# Reset cooldown timer - it will count up during idle animation
		if attack_cooldown > 0.0:
			time_since_attack = 0.0


func _on_animation_frame_changed() -> void:
	"""Called when AnimatedSprite2D frame changes. Checks if we're on the attack damage frame."""
	if not is_attacking:
		return
	
	# Only trigger on attack animation
	if animated_sprite.animation != "attack":
		return
	
	# Check if we're on the damage frame and haven't triggered yet
	if animated_sprite.frame == attack_damage_frame and not has_triggered_frame_damage:
		_trigger_attack_damage()


## Virtual method - subclasses override to customize behavior on attack frame
## Melee units: play damage sound and deal damage
## Ranged units: play fire sound and spawn projectile
func _trigger_attack_damage() -> void:
	"""Called on the attack damage frame. Default behavior handles melee attacks."""
	has_triggered_frame_damage = true
	_execute_attack()


## Virtual method - subclasses override this to implement their attack type
## Melee units: deal damage directly to target
## Ranged units: spawn projectiles (damage happens when projectiles hit)
## Default implementation does nothing - subclasses must override
func _execute_attack() -> void:
	# Base implementation does nothing - subclasses override
	pass


func _is_combat_active() -> bool:
	"""Check if combat is still active by finding the Game node and checking phase."""
	var game: Game = get_tree().get_first_node_in_group("game") as Game
	if game == null:
		# If we can't find the game node, assume combat is active (fail-safe)
		return true
	
	return game.phase == "battle"


func take_damage(amount: int, attacker_armor_piercing: bool = false) -> void:
	# Ignore damage if already dead/dying
	if state == "dying" or current_hp <= 0:
		return
	
	# Don't take damage if combat is over
	if not _is_combat_active():
		return
	
	# Apply armor reduction unless attacker has armor piercing
	var final_damage := amount
	if not attacker_armor_piercing:
		final_damage = max(0, amount - armor)
	
	current_hp -= final_damage

	# Visual feedback: flash the sprite red
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		# Reset color after a short delay
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if current_hp <= 0:
		die()


func _reset_color() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func die() -> void:
	# Prevent multiple calls to die()
	if state == "dying":
		return
	
	# Stop all movement and combat
	is_attacking = false
	target = null
	set_state("dying")
	
	# Emit appropriate signal based on unit type
	if is_enemy:
		enemy_unit_died.emit(gold_reward)
	else:
		# Emit signal for player unit death (to remove from army)
		if army_index >= 0:
			player_unit_died.emit(army_index)
	
	# Fade out before removing from scene
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func apply_upgrades() -> void:
	"""Apply upgrade bonuses to base stats and update visual markers."""
	for upgrade_type in upgrades:
		var count: int = upgrades[upgrade_type]
		match upgrade_type:
			"hp":
				max_hp += count
				current_hp = max_hp  # Refresh to new max
			"damage":
				damage += count
	
	_update_upgrade_markers()


func _safe_play_animation(anim_name: String) -> void:
	"""Safely play an animation, checking if it exists first."""
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)


func _play_damage_sound() -> void:
	"""Play a random damage sound effect from the damage_sounds array."""
	if damage_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % damage_sounds.size()
	var sound: AudioStream = damage_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _play_fire_sound() -> void:
	"""Play a random fire sound effect from the fire_sounds array."""
	if fire_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % fire_sounds.size()
	var sound: AudioStream = fire_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _play_impact_sound() -> void:
	"""Play a random impact sound effect from the impact_sounds array."""
	if impact_sounds.is_empty():
		return
	if audio_player == null:
		return
	
	# Pick a random sound from the array
	var random_index := randi() % impact_sounds.size()
	var sound: AudioStream = impact_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()


func _update_upgrade_markers() -> void:
	"""Show the appropriate upgrade marker based on total upgrade count."""
	var upgrade_markers := get_node_or_null("UpgradeMarkers")
	if upgrade_markers == null:
		return
	
	var marker_1 := upgrade_markers.get_node_or_null("Marker1") as Sprite2D
	var marker_2 := upgrade_markers.get_node_or_null("Marker2") as Sprite2D
	var marker_3 := upgrade_markers.get_node_or_null("Marker3") as Sprite2D
	
	if marker_1 == null or marker_2 == null or marker_3 == null:
		return
	
	var total := 0
	for count in upgrades.values():
		total += count
	
	marker_1.visible = (total == 1)
	marker_2.visible = (total == 2)
	marker_3.visible = (total >= 3)
