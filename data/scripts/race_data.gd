class_name RaceData
extends Resource
## Definition of a patron race: hospitality preferences, temperament,
## social relations, and visual identity.
##
## Instances live as [code].tres[/code] files under
## [code]res://data/races/[/code] and are loaded by [code]GameManager[/code].
## Patron behavior, spawning, orders, and tipping all read from this data.

## One signature behavior per race, branched on by patron logic.
enum UniqueTrait {
	GOSSIP, ## Human: extra chatty, spreads good mood to allies.
	WAR_TOAST, ## Orc: roars a toast after the first drink.
	ALOOF, ## Elf: picks isolated seats, leaves if crowded.
	SECOND_ROUND, ## Dwarf: always orders a second drink.
	SECOND_LUNCH, ## Halfling: always orders a second meal.
	COIN_SKIM, ## Goblin: chance to underpay and skip the tip.
	GRAVE_CHILL, ## Undead: unsettles neighbors, rarely speaks, never eats.
}

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

@export_group("Temperament")

## Likelihood of starting trouble when angry (0 = meek, 1 = brawler).
@export_range(0.0, 1.0, 0.05) var aggression: float = 0.2

## Chattiness and how long the patron lingers after eating.
@export_range(0.0, 1.0, 0.05) var sociability: float = 0.5

## Multiplier on how fast thirst builds for this race.
@export_range(0.0, 2.0, 0.05) var thirst_rate: float = 1.0

## Multiplier on how fast hunger builds. Zero means the race never eats.
@export_range(0.0, 2.0, 0.05) var hunger_rate: float = 1.0

## The race's signature behavior quirk.
@export var unique_trait: UniqueTrait = UniqueTrait.GOSSIP

@export_group("Preferences")

## Drink item ids this race orders, in preference order.
@export var preferred_drink_ids: Array[StringName] = []

## Food item ids this race orders. Empty means the race never orders food.
@export var preferred_food_ids: Array[StringName] = []

## Races this one enjoys sitting near.
@export var ally_race_ids: Array[StringName] = []

## Races this one resents; fuel for bad moods and brawls.
@export var enemy_race_ids: Array[StringName] = []

@export_group("Appearance")

## Skin/body tint for the generated NPC body.
@export var body_color: Color = Color(0.76, 0.6, 0.42)

## Height multiplier applied to the standard NPC body.
@export_range(0.5, 1.5, 0.05) var height_scale: float = 1.0

## First names used when generating patrons of this race.
@export var given_names: Array[String] = []


## True when [param item_id] is one of this race's favorites.
func favors_item(item_id: StringName) -> bool:
	return favorite_item_ids.has(item_id)


## True when this race resents [param other_race_id].
func is_enemy_of(other_race_id: StringName) -> bool:
	return enemy_race_ids.has(other_race_id)


## True when this race enjoys the company of [param other_race_id].
func is_ally_of(other_race_id: StringName) -> bool:
	return ally_race_ids.has(other_race_id)
