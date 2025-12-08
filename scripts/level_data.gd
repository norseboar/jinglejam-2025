extends Resource
class_name LevelData

## Low multiplier for enemy army value (e.g., 0.8 = 80% of player army value)
@export var low_multiplier: float = 0.8

## High multiplier for enemy army value (e.g., 1.2 = 120% of player army value)
@export var high_multiplier: float = 1.2

## Minimum gold value for enemy armies (overrides multiplier if needed)
@export var minimum_gold: int = 0

## Units that must appear in both battle options (drafted first)
@export var forced_units: Array[PackedScene] = []

## Optional neutral roster to include in unit pool
@export var neutral_roster: Roster = null

## If true, use intense music variant from enemy roster
@export var use_intense_music: bool = false
