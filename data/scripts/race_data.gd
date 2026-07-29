class_name RaceData
extends Resource
## Definition of a patron race and its hospitality preferences.
##
## Instances live as [code].tres[/code] files under
## [code]res://data/races/[/code] and are loaded by [code]GameManager[/code].
## Later phases use these to drive patron spawning, orders, and tipping.

## Stable identifier used in saves and patron generation.
@export var id: StringName = &""

## Player-facing race name.
@export var display_name: String = ""

@export_multiline var description: String = ""

## Item ids this race favors; serving one improves mood and tips.
@export var favorite_item_ids: Array[StringName] = []

## Multiplier applied to tips from satisfied patrons of this race.
@export_range(0.25, 4.0, 0.05) var tip_multiplier: float = 1.0

## Seconds a patron of this race waits before growing impatient.
@export_range(10.0, 600.0, 1.0) var patience_seconds: float = 90.0

## Base walking speed in meters per second for patron movement.
@export_range(0.5, 6.0, 0.1) var walk_speed: float = 2.0


## True when [param item_id] is one of this race's favorites.
func favors_item(item_id: StringName) -> bool:
	return favorite_item_ids.has(item_id)
