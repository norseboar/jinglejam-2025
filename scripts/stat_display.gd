extends Control
class_name StatDisplay

@export var icon: TextureRect
@export var value_label: Label


func set_stat(icon_texture: Texture2D, stat_value: int) -> void:
	"""Set the icon and value for this stat display."""
	if icon:
		icon.texture = icon_texture
	if value_label:
		value_label.text = str(stat_value)
