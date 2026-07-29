extends Node
## In-game calendar and clock.
##
## Advances a day/hour/minute clock while the game runs and notifies
## listeners on minute, hour, and day boundaries. The clock is intended to
## drive lighting moods, patron schedules, and opening hours in later phases.
## Autoload name: [code]TimeManager[/code].

## Emitted every time the in-game minute changes.
signal minute_passed(day: int, hour: int, minute: int)

## Emitted every time the in-game hour changes.
signal hour_passed(day: int, hour: int)

## Emitted when the clock rolls past midnight.
signal day_passed(day: int)

## Emitted when [member time_scale] or [member paused] changes.
signal flow_changed

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DEFAULT_REAL_SECONDS_PER_GAME_MINUTE: float = 2.0
const EVENING_OPEN_HOUR: int = 17
const NIGHT_CLOSE_HOUR: int = 2

var day: int = 1
var hour: int = 18
var minute: int = 0

## Real seconds that one in-game minute takes. Lower = faster days.
var real_seconds_per_game_minute: float = DEFAULT_REAL_SECONDS_PER_GAME_MINUTE:
	set(value):
		real_seconds_per_game_minute = maxf(0.05, value)
		flow_changed.emit()

## When true the in-game clock stops (menus, dialogue, etc.).
var clock_paused: bool = false:
	set(value):
		if clock_paused == value:
			return
		clock_paused = value
		flow_changed.emit()

var _minute_accumulator: float = 0.0


func _process(delta: float) -> void:
	if clock_paused:
		return
	_minute_accumulator += delta
	while _minute_accumulator >= real_seconds_per_game_minute:
		_minute_accumulator -= real_seconds_per_game_minute
		_advance_minute()


## Fraction through the current day in [0, 1), where 0.0 is midnight.
func day_progress() -> float:
	var minutes_today: int = hour * MINUTES_PER_HOUR + minute
	return float(minutes_today) / float(HOURS_PER_DAY * MINUTES_PER_HOUR)


## True during the tavern's busy evening window.
func is_open_hours() -> bool:
	return hour >= EVENING_OPEN_HOUR or hour < NIGHT_CLOSE_HOUR


## Sets the clock directly (used by SaveManager on load).
func set_clock(new_day: int, new_hour: int, new_minute: int) -> void:
	day = maxi(1, new_day)
	hour = clampi(new_hour, 0, HOURS_PER_DAY - 1)
	minute = clampi(new_minute, 0, MINUTES_PER_HOUR - 1)
	_minute_accumulator = 0.0
	minute_passed.emit(day, hour, minute)


## Formatted "Day N - HH:MM" string for HUD display.
func clock_text() -> String:
	return StringUtils.format_day_clock(day, hour, minute)


func _advance_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_HOUR:
		minute = 0
		hour += 1
		if hour >= HOURS_PER_DAY:
			hour = 0
			day += 1
			day_passed.emit(day)
		hour_passed.emit(day, hour)
	minute_passed.emit(day, hour, minute)
