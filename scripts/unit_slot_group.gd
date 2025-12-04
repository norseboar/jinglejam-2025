extends Control
class_name UnitSlotGroup

# Selection mode enum
enum SelectionMode {
	NONE,   # No selection
	CLICK,  # Select on click
	HOVER   # Select on hover
}

# Configuration
@export var enable_drag_drop: bool = false  # Enable drag-and-drop for all slots in this group
@export var selection_mode: SelectionMode = SelectionMode.CLICK  # How slots are selected

# State
var slots: Array[UnitSlot] = []

func _ready() -> void:
	# Collect all UnitSlot children
	_collect_slots()
	
	# Set up drag-and-drop based on configuration
	_update_drag_drop_state()
	
	# Set selection mode on all slots
	_update_selection_mode()
	
	# Connect to each slot's signals for selection management
	_connect_slot_signals()

func _collect_slots() -> void:
	"""Collect all UnitSlot children."""
	slots.clear()
	for child in get_children():
		if child is UnitSlot:
			var slot := child as UnitSlot
			slots.append(slot)
			slot.slot_index = slots.size() - 1

func _update_drag_drop_state() -> void:
	"""Enable or disable drag-and-drop on all slots based on configuration."""
	for slot in slots:
		slot.enable_drag_drop = enable_drag_drop

func _update_selection_mode() -> void:
	"""Set selection mode on all slots based on configuration."""
	for slot in slots:
		# Convert between enum types using match (enums are different types)
		match selection_mode:
			SelectionMode.NONE:
				slot.selection_mode = UnitSlot.SelectionMode.NONE
			SelectionMode.CLICK:
				slot.selection_mode = UnitSlot.SelectionMode.CLICK
			SelectionMode.HOVER:
				slot.selection_mode = UnitSlot.SelectionMode.HOVER

func _connect_slot_signals() -> void:
	"""Connect to slot signals for selection management."""
	for slot in slots:
		# Connect hover signal to manage "only one selected at a time"
		if not slot.unit_slot_hovered.is_connected(_on_unit_slot_hovered):
			slot.unit_slot_hovered.connect(_on_unit_slot_hovered)
		# Connect click signal to manage selection when drag-and-drop is disabled
		if not slot.unit_slot_clicked.is_connected(_on_unit_slot_clicked):
			slot.unit_slot_clicked.connect(_on_unit_slot_clicked)

func _on_unit_slot_hovered(hovered_slot: UnitSlot) -> void:
	"""Handle unit slot hover - ensure only one slot is selected at a time (when selection mode is HOVER)."""
	if selection_mode == SelectionMode.HOVER:
		# Deselect all other slots, keeping only the hovered one selected
		for slot in slots:
			if slot != hovered_slot:
				slot.set_selected(false)

func _on_unit_slot_clicked(clicked_slot: UnitSlot) -> void:
	"""Handle unit slot click - select clicked slot and deselect others (when selection mode is CLICK)."""
	if selection_mode == SelectionMode.CLICK:
		# Only select if slot has a unit
		if clicked_slot.current_army_unit:
			# Deselect all other slots, select the clicked one
			for slot in slots:
				slot.set_selected(slot == clicked_slot)

