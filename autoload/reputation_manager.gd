extends Node
## Per-race and overall standing of the tavern with its clientele.
##
## Reputation is 0-100 per race (50 = neutral). Good service, favorite
## dishes, and safe evenings raise it; long waits, brawls, and being thrown
## out lower it. It scales patron spawn weights, starting mood, and tips.
## Autoload name: [code]ReputationManager[/code].

## Emitted when a race's reputation changes.
signal reputation_changed(race_id: StringName, value: float)

const MIN_REPUTATION: float = 0.0
const MAX_REPUTATION: float = 100.0
const NEUTRAL_REPUTATION: float = 50.0

## Spawn-weight multiplier at 0 and at 100 reputation.
const SPAWN_FACTOR_MIN: float = 0.35
const SPAWN_FACTOR_MAX: float = 1.8

## Starting-mood offset at reputation extremes (+/-).
const MOOD_OFFSET_RANGE: float = 0.15

## Tip multiplier bonus at maximum reputation.
const TIP_BONUS_MAX: float = 0.5

var _reputation: Dictionary[StringName, float] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)


## Current reputation with [param race_id] (neutral when unknown).
func get_reputation(race_id: StringName) -> float:
	return _reputation.get(race_id, NEUTRAL_REPUTATION)


## Adjusts a race's standing by [param delta] points.
func adjust(race_id: StringName, delta: float) -> void:
	if race_id == &"":
		return
	var value: float = clampf(
		get_reputation(race_id) + delta, MIN_REPUTATION, MAX_REPUTATION
	)
	_reputation[race_id] = value
	reputation_changed.emit(race_id, value)


## Adjusts every known race at once (city-wide word of mouth).
func adjust_all(delta: float) -> void:
	for race: RaceData in GameManager.get_all_races():
		adjust(race.id, delta)


## Sets a race's standing directly (save loading).
func set_reputation(race_id: StringName, value: float) -> void:
	_reputation[race_id] = clampf(value, MIN_REPUTATION, MAX_REPUTATION)
	reputation_changed.emit(race_id, _reputation[race_id])


## Average standing across all known races.
func overall() -> float:
	var races: Array[RaceData] = GameManager.get_all_races()
	if races.is_empty():
		return NEUTRAL_REPUTATION
	var total: float = 0.0
	for race: RaceData in races:
		total += get_reputation(race.id)
	return total / float(races.size())


## Spawn-weight multiplier for [param race_id] (higher rep = more visits).
func spawn_weight_multiplier(race_id: StringName) -> float:
	return lerpf(
		SPAWN_FACTOR_MIN, SPAWN_FACTOR_MAX,
		get_reputation(race_id) / MAX_REPUTATION
	)


## Mood offset applied to new patrons of [param race_id] (-range..+range).
func starting_mood_offset(race_id: StringName) -> float:
	var normalized: float = get_reputation(race_id) / MAX_REPUTATION
	return (normalized - 0.5) * 2.0 * MOOD_OFFSET_RANGE


## Extra tip fraction earned from [param race_id] at high standing.
func tip_bonus_fraction(race_id: StringName) -> float:
	var normalized: float = get_reputation(race_id) / MAX_REPUTATION
	return maxf(0.0, normalized - 0.5) * 2.0 * TIP_BONUS_MAX


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.reputation.clear()
	for race_id: StringName in _reputation:
		data.reputation[String(race_id)] = _reputation[race_id]


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	_reputation.clear()
	for race_key: String in data.reputation:
		set_reputation(StringName(race_key), float(data.reputation[race_key]))
