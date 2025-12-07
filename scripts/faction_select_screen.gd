extends Control
class_name FactionSelectScreen

signal roster_selected(roster: Roster)

const DEFAULT_STARTING_ROSTER_PATHS := [
	"res://units/rosters/starting_rosters/humans.tres",
	"res://units/rosters/starting_rosters/dwarves.tres",
	"res://units/rosters/starting_rosters/demons.tres",
]

@export var slot_group: UnitSlotGroup
@export var confirm_button: BaseButton
@export var faction_name_label: Label
@export var rosters: Array[Roster] = []
@export var background_texture: Texture2D

var available_rosters: Array[Roster] = []
var selected_index: int = -1

func _ready() -> void:
	# Hide by default until explicitly shown
	visible = false
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	_setup_slots()
	_update_confirm_state()


func show_selector() -> void:
	"""Show the selector modal and reset state."""
	available_rosters = _get_available_rosters()
	print("FactionSelect: loaded %d rosters" % available_rosters.size())
	_apply_background_texture()
	_populate_slots()
	if available_rosters.size() > 0:
		_select_index(0)
	else:
		_select_index(-1)
	visible = true


func hide_selector() -> void:
	visible = false


func _setup_slots() -> void:
	var slots := _get_slots()
	for slot in slots:
		if not slot.unit_slot_clicked.is_connected(_on_slot_clicked):
			slot.unit_slot_clicked.connect(_on_slot_clicked)
		slot.set_selected(false)
	_update_confirm_state()


func _get_slots() -> Array[UnitSlot]:
	if slot_group:
		return slot_group.slots
	return []


func _get_available_rosters() -> Array[Roster]:
	var result: Array[Roster] = []
	for roster in rosters:
		if roster:
			result.append(roster)
	
	if result.is_empty():
		for path in DEFAULT_STARTING_ROSTER_PATHS:
			if ResourceLoader.exists(path):
				var loaded := load(path) as Roster
				if loaded:
					result.append(loaded)
	return result


func _populate_slots() -> void:
	var slots := _get_slots()
	for i in range(slots.size()):
		var slot := slots[i]
		var roster: Roster = null
		if i < available_rosters.size():
			roster = available_rosters[i]
		_assign_roster_to_slot(slot, roster)


func _assign_roster_to_slot(slot: UnitSlot, roster: Roster) -> void:
	if slot == null:
		return
	# Keep whatever sprite is authored in the scene for faction preview slots
	slot.override_sprite_frames = false
	slot.set_selected(false)
	if roster and not roster.units.is_empty():
		var preview_unit := ArmyUnit.new()
		preview_unit.unit_scene = roster.units[0]
		preview_unit.unit_type = preview_unit.unit_scene.resource_path.get_file().get_basename()
		preview_unit.upgrades = {}
		preview_unit.placed = false
		slot.set_unit(preview_unit)
		slot.tooltip_text = roster.team_name
	else:
		slot.set_unit(null)
		slot.tooltip_text = ""


func _on_slot_clicked(slot: UnitSlot) -> void:
	if slot == null:
		return
	_select_index(slot.slot_index)


func _select_index(index: int) -> void:
	var slots := _get_slots()
	selected_index = index
	for i in range(slots.size()):
		slots[i].set_selected(i == index and index >= 0)
	_update_confirm_state()
	_update_faction_label()


func _update_confirm_state() -> void:
	if confirm_button:
		confirm_button.disabled = selected_index < 0


func _update_faction_label() -> void:
	if not faction_name_label:
		return
	if selected_index >= 0 and selected_index < available_rosters.size():
		var roster := available_rosters[selected_index]
		faction_name_label.text = roster.team_name
	else:
		faction_name_label.text = ""


func _on_confirm_pressed() -> void:
	if selected_index < 0 or selected_index >= available_rosters.size():
		print("FactionSelect: confirm ignored, invalid index %d" % selected_index)
		return
	var roster := available_rosters[selected_index]
	if roster == null:
		print("FactionSelect: confirm ignored, roster null at index %d" % selected_index)
		return
	print("FactionSelect: confirmed roster '%s'" % roster.team_name)
	hide_selector()
	roster_selected.emit(roster)


func _apply_background_texture() -> void:
	"""Apply this screen's background texture to the game's background, if available."""
	if background_texture == null:
		return
	var game := _get_game()
	if game and game.background_rect:
		game.background_rect.texture = background_texture


func _get_game() -> Game:
	return get_tree().get_first_node_in_group("game") as Game

