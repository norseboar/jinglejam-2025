extends Control
class_name UpgradeSlot

signal slot_clicked(slot_index: int)

@export var texture_rect: TextureRect
@export var selection_highlight: ColorRect

var slot_index: int = -1


func _ready() -> void:
	# Ensure selection highlight is hidden initially
	if selection_highlight:
		selection_highlight.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)
			accept_event()


func set_selected(selected: bool) -> void:
	"""Show or hide the selection highlight."""
	if selection_highlight:
		selection_highlight.visible = selected


func set_unit_texture(texture: Texture2D) -> void:
	"""Set the unit texture to display in this slot."""
	if texture_rect:
		texture_rect.texture = texture


func has_unit() -> bool:
	"""Check if this slot has a unit texture assigned."""
	return texture_rect != null and texture_rect.texture != null

