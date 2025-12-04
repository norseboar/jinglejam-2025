extends Node2D
class_name Unit

# Signals
signal enemy_unit_died(gold_reward: int)  # Emitted by enemies with gold_reward
signal player_unit_died(army_index: int)  # Emitted by player units with army_index

# Stats
@export var max_hp := 3
@export var current_hp := 3
@export var damage := 1
@export var speed := 100.0           # pixels per second
@export var attack_range := 50.0     # radius to detect enemies
@export var attack_cooldown := 1.0   # seconds between attacks

# Display info
@export var display_name: String = "Unit"
@export var description: String = "A basic unit."

# Gold system properties
@export var base_recruit_cost := 10  # Base cost to recruit this unit type
@export var upgrade_cost := 5  # Cost per upgrade (HP or Damage)
@export var gold_reward := 5  # Gold given when this unit is killed

# State
var is_enemy := false        # true = moves left (enemy), false = moves right (player)
var state := "idle"          # "idle" | "moving" | "fighting" | "dying"
var target: Node2D = null    # current attack target
var time_since_attack := 0.0 # timer for attack cooldown
var is_attacking := false    # true when attack animation is playing
var army_index := -1         # Index in Game.army array, or -1 if not from army

# Upgrades
var upgrades: Dictionary = {}  # e.g., { "hp": 2, "damage": 1 }

# Reference to the container holding enemies (set by Game.gd when spawning)
var enemy_container: Node2D = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_hp = max_hp
	# Flip sprite to face correct direction based on team
	# This must happen in _ready() so enemies face the correct direction immediately
	if animated_sprite:
		animated_sprite.flip_h = is_enemy
		_safe_play_animation("idle")


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
	# Determine movement direction based on team
	var direction := 1.0 if not is_enemy else -1.0  # Player moves right, enemy moves left

	# Flip sprite to face movement direction
	animated_sprite.flip_h = is_enemy

	# Move horizontally
	position.x += direction * speed * delta

	# Check for enemies in range
	_check_for_targets()


func _check_for_targets() -> void:
	if enemy_container == null:
		return

	var closest_enemy: Node2D = null
	var closest_distance := INF

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
		if distance < attack_range and distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		set_state("fighting")
		time_since_attack = attack_cooldown  # Attack immediately when entering combat


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

	# Check if target moved out of range
	var distance := position.distance_to(target.position)
	if distance > attack_range * 1.2:  # Small buffer to prevent flickering
		target = null
		set_state("moving")
		return

	# Attack on cooldown (only if not already attacking)
	if not is_attacking:
		time_since_attack += delta
		if time_since_attack >= attack_cooldown:
			time_since_attack = 0.0
			_attack_target()


func _attack_target() -> void:
	if target == null or not is_instance_valid(target) or is_attacking:
		return

	# Set attacking flag and play animation
	is_attacking = true
	
	# Calculate animation speed to match attack cooldown
	var anim_speed_scale := _calculate_attack_animation_speed()
	animated_sprite.speed_scale = anim_speed_scale
	_safe_play_animation("attack")

	# Get animation duration (accounting for speed scale)
	var anim_duration := _get_attack_animation_duration() / anim_speed_scale
	
	if anim_duration > 0:
		get_tree().create_timer(anim_duration).timeout.connect(_on_attack_animation_finished)
	else:
		_on_attack_animation_finished()


func _calculate_attack_animation_speed() -> float:
	var base_duration := _get_attack_animation_duration()
	if base_duration <= 0 or attack_cooldown <= 0:
		return 1.0
	# Scale animation to fit within attack cooldown
	# Leave a small buffer so animation completes before next attack
	var target_duration := attack_cooldown * 0.9
	return base_duration / target_duration


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
	is_attacking = false
	
	# Reset animation speed scale
	animated_sprite.speed_scale = 1.0
	
	# Call virtual method for actual attack effect (subclasses override this)
	_apply_attack_damage()
	
	# Switch back to idle animation while waiting for next attack
	if state == "fighting" and animated_sprite:
		_safe_play_animation("idle")


## Virtual method - subclasses override this to implement their attack type
func _apply_attack_damage() -> void:
	# Default melee behavior - deal damage directly to target
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)


func take_damage(amount: int) -> void:
	# Ignore damage if already dead/dying
	if state == "dying" or current_hp <= 0:
		return
	
	current_hp -= amount

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
