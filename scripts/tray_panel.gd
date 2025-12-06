extends MarginContainer
class_name TrayPanel

@export var slide_distance: float = 140.0
@export var slide_duration: float = 0.25
@export var slide_transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var slide_ease: Tween.EaseType = Tween.EASE_IN_OUT

var _home_position: Vector2
var _tween: Tween = null

func _ready() -> void:
	# Store the resting position so we can animate relative to it
	_home_position = position


func slide_out() -> void:
	"""Animate the tray downward and hide it once the tween completes."""
	if not is_inside_tree():
		return
	visible = true
	_start_tween(_home_position + Vector2(0, slide_distance), false)


func slide_in() -> void:
	"""Bring the tray back to its home position."""
	if not is_inside_tree():
		return
	if not visible:
		# Start from the hidden position so the tween travels upward
		position = _home_position + Vector2(0, slide_distance)
		visible = true
	_start_tween(_home_position, true)


func hide_immediately() -> void:
	"""Hide the tray without animation (used when leaving battle flow)."""
	_clear_tween()
	position = _home_position
	visible = false


func reset_to_home() -> void:
	"""Reset to the home position and ensure visibility."""
	_clear_tween()
	position = _home_position
	visible = true


func _start_tween(target: Vector2, should_show: bool) -> void:
	_clear_tween()
	_tween = create_tween()
	_tween.set_trans(slide_transition)
	_tween.set_ease(slide_ease)
	_tween.tween_property(self, "position", target, slide_duration)
	if not should_show:
		_tween.tween_callback(func() -> void:
			visible = false
		)


func _clear_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

