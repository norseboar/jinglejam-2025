extends Resource
class_name Roster

## Display name for this roster/faction (e.g., "Human Army", "Dwarf Clan")
@export var team_name: String = "Unknown Army"

## Array of unit scenes available in this roster.
## For starting rosters: duplicates allowed (e.g., 4 squires to draft from)
## For full rosters: one entry per unit type (used for enemy generation)
@export var units: Array[PackedScene] = []

## Array of battlefield scenes this roster can fight on (full rosters only)
@export var battlefields: Array[PackedScene] = []

## Chance to upgrade an existing unit vs adding a new unit during army generation (0.0 to 1.0)
## Higher values = fewer but more upgraded units. Lower values = more units with fewer upgrades.
@export_range(0.0, 1.0) var upgrade_ratio := 0.3

## Music track to play during battles against this faction
@export var battle_music: AudioStream

## Intense variant battle music (used when level specifies use_intense_music)
@export var battle_music_intense: AudioStream = null
