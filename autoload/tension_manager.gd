extends Node
## Global room-tension meter: the single source of truth for how close the
## tavern is to boiling over.
##
## Tension lives on a 0-100 scale with CALM / UNEASY / CRITICAL bands.
## NPC incidents, service failures, and brawls push it up; time, upgrades,
## and player hospitality pull it down. Level crossings emit warning and
## critical events for the HUD and future quest hooks.
## Autoload name: [code]TensionManager[/code].

## Emitted whenever the tension value changes.
signal tension_changed(tension: float)

## Emitted when the tension band changes.
signal level_changed(level: Level)

## Emitted on entering the UNEASY band from below.
signal warning_reached

## Emitted on entering the CRITICAL band.
signal critical_reached

enum Level {
	CALM,
	UNEASY,
	CRITICAL,
}

const MIN_TENSION: float = 0.0
const MAX_TENSION: float = 100.0
const WARNING_THRESHOLD: float = 40.0
const CRITICAL_THRESHOLD: float = 75.0
const START_TENSION: float = 10.0

## Passive decay per second while the room settles.
const DECAY_PER_SECOND: float = 0.35

## Seconds between decay ticks (kept off the frame loop).
const DECAY_TICK_SECONDS: float = 1.0

## Patron brawl-chance multiplier range across the tension scale.
const BRAWL_FACTOR_CALM: float = 0.3
const BRAWL_FACTOR_CRITICAL: float = 2.5

var tension: float = START_TENSION

var _decay_timer: Timer = null


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_decay_timer = Timer.new()
	_decay_timer.name = "DecayTimer"
	_decay_timer.wait_time = DECAY_TICK_SECONDS
	_decay_timer.one_shot = false
	_decay_timer.autostart = true
	add_child(_decay_timer)
	_decay_timer.timeout.connect(_on_decay_tick)


## Raises tension by [param amount]. [param reason] feeds logs/notifications.
func add_tension(amount: float, reason: String = "") -> void:
	if amount <= 0.0:
		return
	_set_tension(tension + amount)
	if not reason.is_empty() and level() == Level.CRITICAL:
		EventBus.post_notification("The room bristles: %s" % reason)


## Lowers tension by [param amount].
func reduce_tension(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_tension(tension - amount)


## Sets tension directly (used by save loading).
func set_tension(value: float) -> void:
	_set_tension(value)


## The current band for [member tension].
func level() -> Level:
	if tension >= CRITICAL_THRESHOLD:
		return Level.CRITICAL
	if tension >= WARNING_THRESHOLD:
		return Level.UNEASY
	return Level.CALM


func is_critical() -> bool:
	return level() == Level.CRITICAL


## Normalized tension in [0, 1] for UI bars.
func fraction() -> float:
	return tension / MAX_TENSION


## Multiplier patrons apply to their brawl chance rolls.
func brawl_chance_multiplier() -> float:
	return lerpf(BRAWL_FACTOR_CALM, BRAWL_FACTOR_CRITICAL, fraction())


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.tension = tension


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	set_tension(data.tension)


func _set_tension(value: float) -> void:
	var previous_level: Level = level()
	var clamped: float = clampf(value, MIN_TENSION, MAX_TENSION)
	if is_equal_approx(clamped, tension):
		return
	tension = clamped
	tension_changed.emit(tension)
	var new_level: Level = level()
	if new_level == previous_level:
		return
	level_changed.emit(new_level)
	if new_level == Level.UNEASY and previous_level == Level.CALM:
		warning_reached.emit()
	elif new_level == Level.CRITICAL:
		critical_reached.emit()


func _on_decay_tick() -> void:
	if get_tree().paused:
		return
	var bonus: float = UpgradeManager.effect_value(&"tension_decay_bonus")
	reduce_tension(DECAY_PER_SECOND * DECAY_TICK_SECONDS * (1.0 + bonus))
