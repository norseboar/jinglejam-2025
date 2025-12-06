extends TextureButton
## Simple always-visible sound toggle button. Attach to a TextureButton and
## assign the on/off textures in the inspector. Toggling mutes/unmutes the
## chosen audio bus (default: Master).

@export var bus_name: String = "Master"
@export var sound_on_texture: Texture2D
@export var sound_off_texture: Texture2D
@export var start_muted: bool = false  # Optional override for initial state


func _ready() -> void:
	# Ensure the button behaves as a toggle
	toggle_mode = true
	button_pressed = false
	
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("SoundToggleButton: Bus '%s' not found; using Master" % bus_name)
		bus_index = AudioServer.get_bus_index("Master")
	
	# Initialize mute state (explicit start_muted takes priority)
	var muted := start_muted
	if not start_muted and bus_index != -1:
		muted = AudioServer.is_bus_mute(bus_index)
	_apply_mute_state(muted, bus_index)
	
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("SoundToggleButton: Bus '%s' not found; cannot toggle" % bus_name)
		return
	
	var muted := not AudioServer.is_bus_mute(bus_index)
	_apply_mute_state(muted, bus_index)


func _apply_mute_state(muted: bool, bus_index: int) -> void:
	AudioServer.set_bus_mute(bus_index, muted)
	button_pressed = muted
	_update_textures(muted)


func _update_textures(muted: bool) -> void:
	# Swap textures based on current mute state
	if muted:
		if sound_off_texture:
			texture_normal = sound_off_texture
			texture_pressed = sound_off_texture
			texture_hover = sound_off_texture
			texture_disabled = sound_off_texture
	else:
		if sound_on_texture:
			texture_normal = sound_on_texture
			texture_pressed = sound_on_texture
			texture_hover = sound_on_texture
			texture_disabled = sound_on_texture
