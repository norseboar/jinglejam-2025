extends Node2D

@export var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_update_cover_scale()
	get_viewport().size_changed.connect(_update_cover_scale)

func _update_cover_scale() -> void:
	var tex_size := _get_texture_size()
	if tex_size == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	# Center the node so the cover scaling crops evenly.
	position = vp_size * 0.5
	var factor: float = max(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	scale = base_scale * Vector2(factor, factor)
	print("cover tex_size:", tex_size, " vp:", vp_size, " factor:", factor, " pos:", position)

func _get_texture_size() -> Vector2:
	# Sprite2D path
	if has_method("get_texture"):
		var tex = call("get_texture")
		if tex != null:
			var size: Vector2 = tex.get_size()
			# Handle region-enabled sprites
			if has_method("is_region_enabled") and call("is_region_enabled"):
				if has_method("get_region_rect"):
					size = call("get_region_rect").size
			return size
	# AnimatedSprite2D path
	if has_method("get_sprite_frames"):
		var frames = call("get_sprite_frames")
		if frames != null and frames.has_animation(call("get_animation")):
			var tex = frames.get_frame_texture(call("get_animation"), call("get_frame"))
			if tex != null:
				return tex.get_size()
	return Vector2.ZERO
