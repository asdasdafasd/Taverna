class_name SaveData
extends Resource
## In-memory model of one save slot, serialized to JSON on disk.
##
## Systems that persist state join the [code]SaveManager.SAVE_GROUP[/code]
## group and implement [code]write_save_data(data)[/code] and
## [code]read_save_data(data)[/code].

## Bump when the on-disk format changes incompatibly.
const CURRENT_VERSION: int = 1

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
	}


## Populates this instance from a parsed JSON dictionary.
## Returns false when the payload is missing or incompatible.
func from_dict(source: Dictionary) -> bool:
	var read_version: int = int(source.get("version", 0))
	if read_version != CURRENT_VERSION:
		return false
	version = read_version
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
	return true
