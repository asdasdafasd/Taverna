class_name SaveData
extends Resource
## In-memory model of one save slot, serialized to JSON on disk.
##
## Systems that persist state join the [code]SaveManager.SAVE_GROUP[/code]
## group and implement [code]write_save_data(data)[/code] and
## [code]read_save_data(data)[/code].

## Bump when the on-disk format changes incompatibly.
const CURRENT_VERSION: int = 3

## Oldest version [method from_dict] can still read (newer fields default).
const MIN_COMPATIBLE_VERSION: int = 2

var version: int = CURRENT_VERSION

## ISO-8601 wall-clock timestamp of when the save was written.
var saved_at: String = ""

## Total real seconds of play across the session's lifetime.
var play_time_seconds: float = 0.0

## In-game calendar/clock state.
var day: int = 1
var hour: int = 18
var minute: int = 0

## Tavern funds in copper coins.
var gold_copper: int = 0

## Player placement inside the tavern.
var player_position: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0

## Room tension (0-100).
var tension: float = 10.0

## Race id -> reputation value (0-100).
var reputation: Dictionary[String, float] = {}

## Ids of purchased upgrades.
var owned_upgrades: Array[String] = []

## Item id -> stock units.
var stock: Dictionary[String, int] = {}

## Item id -> menu price in copper.
var menu_prices: Dictionary[String, int] = {}

## Day number (as string key) -> [income, expenses] pair in copper.
var ledger_days: Dictionary[String, Array] = {}

## Accumulated unrepaired furniture damage in copper.
var furniture_damage_copper: int = 0

## Raised story flags.
var story_flags: Array[String] = []

## StoryManager.AccordChoice value.
var accord_choice: int = 0

## Quest id -> {"status": int, "progress": [int]}.
var quest_states: Dictionary[String, Dictionary] = {}

## Event id -> in-game day it last fired.
var event_history: Dictionary[String, int] = {}

## Tutorial completion (skipped counts as done).
var tutorial_done: bool = false

## Whether the intro sequence has already played.
var intro_seen: bool = false


func to_dict() -> Dictionary:
	return {
		"version": version,
		"saved_at": saved_at,
		"play_time_seconds": play_time_seconds,
		"day": day,
		"hour": hour,
		"minute": minute,
		"gold_copper": gold_copper,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_yaw": player_yaw,
		"tension": tension,
		"reputation": reputation,
		"owned_upgrades": owned_upgrades,
		"stock": stock,
		"menu_prices": menu_prices,
		"ledger_days": ledger_days,
		"furniture_damage_copper": furniture_damage_copper,
		"story_flags": story_flags,
		"accord_choice": accord_choice,
		"quest_states": quest_states,
		"event_history": event_history,
		"tutorial_done": tutorial_done,
		"intro_seen": intro_seen,
	}


## Populates this instance from a parsed JSON dictionary.
## Returns false when the payload is missing or incompatible.
func from_dict(source: Dictionary) -> bool:
	var read_version: int = int(source.get("version", 0))
	if read_version < MIN_COMPATIBLE_VERSION or read_version > CURRENT_VERSION:
		return false
	version = CURRENT_VERSION
	saved_at = str(source.get("saved_at", ""))
	play_time_seconds = float(source.get("play_time_seconds", 0.0))
	day = maxi(1, int(source.get("day", 1)))
	hour = clampi(int(source.get("hour", 18)), 0, 23)
	minute = clampi(int(source.get("minute", 0)), 0, 59)
	gold_copper = maxi(0, int(source.get("gold_copper", 0)))
	var position_values: Array = source.get("player_position", [])
	if position_values.size() == 3:
		player_position = Vector3(
			float(position_values[0]),
			float(position_values[1]),
			float(position_values[2])
		)
	player_yaw = float(source.get("player_yaw", 0.0))
	tension = clampf(float(source.get("tension", 10.0)), 0.0, 100.0)
	reputation.clear()
	var reputation_source: Dictionary = source.get("reputation", {})
	for race_key: Variant in reputation_source:
		reputation[str(race_key)] = float(reputation_source[race_key])
	owned_upgrades.clear()
	for upgrade_key: Variant in source.get("owned_upgrades", []):
		owned_upgrades.append(str(upgrade_key))
	stock.clear()
	var stock_source: Dictionary = source.get("stock", {})
	for item_key: Variant in stock_source:
		stock[str(item_key)] = int(stock_source[item_key])
	menu_prices.clear()
	var price_source: Dictionary = source.get("menu_prices", {})
	for item_key: Variant in price_source:
		menu_prices[str(item_key)] = int(price_source[item_key])
	ledger_days.clear()
	var ledger_source: Dictionary = source.get("ledger_days", {})
	for day_key: Variant in ledger_source:
		var pair: Variant = ledger_source[day_key]
		if pair is Array and (pair as Array).size() == 2:
			ledger_days[str(day_key)] = pair
	furniture_damage_copper = maxi(0, int(source.get("furniture_damage_copper", 0)))
	story_flags.clear()
	for flag_key: Variant in source.get("story_flags", []):
		story_flags.append(str(flag_key))
	accord_choice = int(source.get("accord_choice", 0))
	quest_states.clear()
	var quest_source: Dictionary = source.get("quest_states", {})
	for quest_key: Variant in quest_source:
		var state: Variant = quest_source[quest_key]
		if state is Dictionary:
			quest_states[str(quest_key)] = state
	event_history.clear()
	var event_source: Dictionary = source.get("event_history", {})
	for event_key: Variant in event_source:
		event_history[str(event_key)] = int(event_source[event_key])
	tutorial_done = bool(source.get("tutorial_done", false))
	intro_seen = bool(source.get("intro_seen", false))
	return true
