extends Node2D
class_name Unit

# Stats
var max_hp := 3
var current_hp := 3
var damage := 1
var speed := 100.0           # pixels per second
var attack_range := 50.0     # radius to detect enemies
var attack_cooldown := 1.0   # seconds between attacks

# State
var is_enemy := false        # true = moves left (enemy), false = moves right (player)
var state := "idle"          # "idle" | "moving" | "fighting" | "dying"
var target: Node2D = null    # current attack target
var time_since_attack := 0.0 # timer for attack cooldown
var is_attacking := false    # true when attack animation is playing

# Reference to the container holding enemies (set by Game.gd when spawning)
var enemy_container: Node2D = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_hp = max_hp
	animated_sprite.play("idle")


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
			animated_sprite.play("idle")
		"moving":
			animated_sprite.play("walk")
		"fighting":
			pass  # Attack animation played per attack
		"dying":
			animated_sprite.play("idle")  # Play idle animation while dying


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
		if enemy is Unit:
			if enemy.current_hp <= 0 or enemy.state == "dying":
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
	# Check if target is still valid
	if not is_instance_valid(target) or target.current_hp <= 0:
		target = null
		set_state("moving")
		return
	
	# Check if target is dying
	if target is Unit and target.state == "dying":
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
	animated_sprite.play("attack")

	# Get animation duration from sprite frames (accounting for custom frame durations)
	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames and sprite_frames.has_animation("attack"):
		var frame_count := sprite_frames.get_frame_count("attack")
		var anim_speed := sprite_frames.get_animation_speed("attack")
		var anim_duration := 0.0
		
		print("Attack animation: frame_count = ", frame_count, ", speed = ", anim_speed, " FPS")
		
		# Sum up individual frame durations to account for custom frame durations
		# get_frame_duration() returns duration in frames, so convert to seconds by dividing by FPS
		for i in range(frame_count):
			var frame_duration_frames := sprite_frames.get_frame_duration("attack", i)
			var frame_duration_seconds := frame_duration_frames / anim_speed
			anim_duration += frame_duration_seconds
			print("  Frame %d duration: %f frames (%f seconds)" % [i, frame_duration_frames, frame_duration_seconds])
		
		print("Total animation duration: %f seconds" % anim_duration)
		
		if anim_duration > 0:
			# Deal damage at the end of the animation
			get_tree().create_timer(anim_duration).timeout.connect(_on_attack_animation_finished)
		else:
			# Fallback if duration is 0 - deal damage immediately
			_on_attack_animation_finished()
	else:
		# Fallback if sprite_frames or animation not found - deal damage immediately
		_on_attack_animation_finished()


func _on_attack_animation_finished() -> void:
	is_attacking = false
	
	# Deal damage when animation finishes
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Switch back to idle animation while waiting for next attack
	if state == "fighting" and animated_sprite:
		animated_sprite.play("idle")


func take_damage(amount: int) -> void:
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
	# Stop all movement and combat
	is_attacking = false
	target = null
	set_state("dying")
	
	# Fade out before removing from scene
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
