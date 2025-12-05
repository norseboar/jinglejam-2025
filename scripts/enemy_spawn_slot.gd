extends Marker2D
class_name EnemySpawnSlot

## Simple position marker for enemy spawn positions on battlefields.
## Unlike EnemyMarker, this does not specify which unit spawns here.
## The generated army determines what spawns at each slot.
##
## Place these in order of priority - slot 0 gets the highest priority unit,
## slot 1 gets the second highest, etc.

func _ready() -> void:
	# Hide visual indicators (Sprite2D children) at runtime - editor-only
	for child in get_children():
		if child is Sprite2D:
			child.visible = false
