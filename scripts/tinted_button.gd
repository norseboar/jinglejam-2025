extends BaseButton
class_name TintedButton

## Button that automatically applies a color tint when disabled using modulate.
## The tint color can be customized via the inspector.

@export var disabled_tint_color: Color = Color8(192, 192, 192, 255)  ## Color to apply when disabled (defaults to 192 gray)

var _original_modulate: Color = Color.WHITE
var _last_disabled_state: bool = false


func _ready() -> void:
	# Store the original modulate value
	_original_modulate = modulate
	_last_disabled_state = disabled
	
	# Apply initial state
	_update_modulate()


func _process(_delta: float) -> void:
	# Check if disabled state changed
	if disabled != _last_disabled_state:
		_last_disabled_state = disabled
		_update_modulate()


func _update_modulate() -> void:
	"""Update the modulate color based on disabled state."""
	if disabled:
		modulate = disabled_tint_color
	else:
		modulate = _original_modulate
