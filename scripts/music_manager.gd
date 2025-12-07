extends Node
## Autoload singleton for managing game music with crossfading
##
## Usage:
##   MusicManager.play_track(MusicManager.title_music)
##   MusicManager.play_track(some_roster.battle_music)

# Music tracks assigned in inspector
@export var title_music: AudioStream
@export var shop_music: AudioStream
@export var victory_jingle: AudioStream
@export var defeat_jingle: AudioStream

# Audio players for crossfading
var current_player: AudioStreamPlayer
var next_player: AudioStreamPlayer
var jingle_player: AudioStreamPlayer

# Crossfade settings
@export var fade_out_duration: float = 1.0  # How long to fade out the old track
@export var fade_in_duration: float = 0.3  # How long to fade in the new track

# State tracking
var current_track: AudioStream = null
var is_crossfading: bool = false


func _ready() -> void:
	# Create two audio players for crossfading
	current_player = AudioStreamPlayer.new()
	next_player = AudioStreamPlayer.new()
	jingle_player = AudioStreamPlayer.new()
	
	add_child(current_player)
	add_child(next_player)
	add_child(jingle_player)
	
	# Set to loop by default (not jingle_player, it's one-shot)
	current_player.bus = "Music"  # Optional: create a Music bus in Godot for volume control
	next_player.bus = "Music"
	jingle_player.bus = "Music"


func play_track(track: AudioStream) -> void:
	"""Play a music track, with crossfading if music is already playing."""
	if track == null:
		push_warning("Attempted to play null music track")
		return
	
	# Don't restart if already playing this track
	if current_track == track and current_player.playing:
		return
	
	# If no music playing, start immediately
	if not current_player.playing:
		_start_track_immediate(track)
		return
	
	# Otherwise, crossfade
	_crossfade_to(track)


func stop_music() -> void:
	"""Stop all music (with fadeout)."""
	if not current_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(current_player, "volume_db", -80, fade_out_duration)
	tween.tween_callback(current_player.stop)
	
	current_track = null


func _start_track_immediate(track: AudioStream) -> void:
	"""Start playing a track immediately without crossfade."""
	current_player.stream = track
	current_player.volume_db = 0
	current_player.play()
	current_track = track


func _crossfade_to(track: AudioStream) -> void:
	"""Crossfade from current track to new track."""
	# Swap players (current becomes old, next becomes current)
	var old_player = current_player
	current_player = next_player
	next_player = old_player
	
	# Start new track on current_player (start silent)
	current_player.stream = track
	current_player.volume_db = -80
	current_player.play()
	current_track = track
	
	# Use a Tween to fade volumes with separate durations
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80, fade_out_duration)
	tween.tween_property(current_player, "volume_db", 0, fade_in_duration)
	
	# Stop old player after fade-out completes using a callback
	var stop_tween = create_tween()
	stop_tween.tween_interval(fade_out_duration)
	stop_tween.tween_callback(old_player.stop)


func play_jingle_and_duck(jingle: AudioStream) -> void:
	"""Play a one-shot jingle and duck the current music."""
	if jingle == null:
		push_warning("Attempted to play null jingle")
		return
	
	# Duck the current music (lower volume)
	if current_player.playing:
		var tween = create_tween()
		tween.tween_property(current_player, "volume_db", -20, 0.5)
	
	# Play the jingle (one-shot, no loop)
	jingle_player.stream = jingle
	jingle_player.volume_db = 0
	jingle_player.play()
	
	# Note: Music stays ducked until next play_track() call, which will crossfade to full volume
