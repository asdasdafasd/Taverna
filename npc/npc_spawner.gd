class_name NPCSpawner
extends Node3D
## Spawns patrons outside the tavern with time-of-day traffic patterns and
## race mixes, and staffs the room with the four employee roles.
##
## Spawning waits for the navigation mesh bake, runs on a timer whose
## cadence follows the busyness curve (lunch bump, dinner rush, night crowd),
## and respects a hard population cap. Race weights shift with the hour so
## daylight brings humans and halflings while goblins and undead own the
## small hours.

## Seconds between spawn attempts at peak busyness.
const SPAWN_INTERVAL_PEAK: float = 6.0

## Seconds between spawn attempts in dead hours.
const SPAWN_INTERVAL_QUIET: float = 45.0

## Busyness per hour of day (0-23); 1 = rush, 0 = closed-feeling.
const HOURLY_BUSYNESS: Array[float] = [
	0.25, 0.15, 0.05, 0.0, 0.0, 0.0, ## 00-05: stragglers, then dead.
	0.05, 0.1, 0.15, 0.2, 0.3, 0.55, ## 06-11: slow morning build.
	0.7, 0.6, 0.35, 0.3, 0.4, 0.7, ## 12-17: lunch bump, lull, pre-dinner.
	1.0, 1.0, 0.9, 0.8, 0.6, 0.4, ## 18-23: dinner rush into night crowd.
]

## Race spawn weights per period. Keys are race ids, values relative weights.
const DAY_RACE_WEIGHTS: Dictionary[StringName, float] = {
	&"human": 4.0, &"halfling": 2.5, &"dwarf": 1.5, &"elf": 0.5,
}
const EVENING_RACE_WEIGHTS: Dictionary[StringName, float] = {
	&"human": 3.0, &"dwarf": 2.5, &"orc": 1.5, &"halfling": 1.5,
	&"elf": 1.0, &"goblin": 0.5,
}
const NIGHT_RACE_WEIGHTS: Dictionary[StringName, float] = {
	&"goblin": 2.5, &"undead": 2.5, &"orc": 2.0, &"human": 1.0,
	&"dwarf": 0.5, &"elf": 0.5,
}

const EVENING_START_HOUR: int = 17
const NIGHT_START_HOUR: int = 21
const DAY_START_HOUR: int = 6

## Staff placement: role posts and stations, in tavern world space.
const BARTENDER_STATION: Vector3 = Vector3(4.2, 0.05, -4.1)
const BARTENDER_POSTS: Array[Vector3] = [
	Vector3(4.2, 0.05, -4.1), Vector3(2.6, 0.05, -4.1),
]
const COOK_STATION: Vector3 = Vector3(3.0, 0.05, -7.8)
const COOK_POSTS: Array[Vector3] = [
	Vector3(2.0, 0.05, -7.8), Vector3(3.6, 0.05, -7.8),
]
const BOUNCER_POSTS: Array[Vector3] = [
	Vector3(1.5, 0.05, 4.0), Vector3(-1.6, 0.05, 4.0),
]
const BARD_POSTS: Array[Vector3] = [
	Vector3(-5.3, 0.05, 1.4),
]

const STAFF_NAMES: Dictionary[String, String] = {
	"bartender": "Odo",
	"cook": "Greta",
	"bouncer": "Brand",
	"bard": "Finch",
}

## Hard cap on simultaneously active patrons.
@export_range(1, 24) var max_patrons: int = 10

## Where patrons appear and despawn (yard, outside the porch).
@export var spawn_point: Vector3 = Vector3(0.7, -0.35, 9.0)

## First indoor waypoint after walking through the entrance.
@export var entrance_point: Vector3 = Vector3(0.0, 0.05, 3.0)

var _patrons_alive: int = 0
var _spawn_timer: Timer = null
var _navigation_ready: bool = false


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	EventBus.navigation_ready.connect(_on_navigation_ready)
	EventBus.patron_left.connect(_on_patron_left)


func _on_navigation_ready() -> void:
	if _navigation_ready:
		return
	_navigation_ready = true
	_spawn_staff()
	_schedule_next_spawn()


func _on_spawn_timer_timeout() -> void:
	_try_spawn_patron()
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	var busyness: float = _current_busyness()
	var interval: float = lerpf(SPAWN_INTERVAL_QUIET, SPAWN_INTERVAL_PEAK, busyness)
	_spawn_timer.start(interval * randf_range(0.8, 1.2))


func _current_busyness() -> float:
	return HOURLY_BUSYNESS[clampi(TimeManager.hour, 0, HOURLY_BUSYNESS.size() - 1)]


func _try_spawn_patron() -> void:
	if _patrons_alive >= max_patrons:
		return
	if _current_busyness() <= 0.0:
		return
	var race: RaceData = _pick_race()
	if race == null:
		return
	var patron: PatronNPC = PatronNPC.new()
	patron.setup(race, entrance_point, spawn_point)
	# Set before add_child so _ready paths from the spawn point (the spawner
	# sits at the world origin, so local position equals world position).
	patron.position = spawn_point
	add_child(patron)
	_patrons_alive += 1


func _on_patron_left(_patron: PatronNPC) -> void:
	_patrons_alive = maxi(0, _patrons_alive - 1)


func _pick_race() -> RaceData:
	var weights: Dictionary[StringName, float] = _weights_for_hour(TimeManager.hour)
	var total: float = 0.0
	for weight: float in weights.values():
		total += weight
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for race_id: StringName in weights:
		roll -= weights[race_id]
		if roll <= 0.0:
			return GameManager.get_race(race_id)
	return GameManager.get_race(weights.keys().back())


func _weights_for_hour(hour: int) -> Dictionary[StringName, float]:
	if hour >= NIGHT_START_HOUR or hour < DAY_START_HOUR:
		return NIGHT_RACE_WEIGHTS
	if hour >= EVENING_START_HOUR:
		return EVENING_RACE_WEIGHTS
	return DAY_RACE_WEIGHTS


func _spawn_staff() -> void:
	var human: RaceData = GameManager.get_race(&"human")
	var bartender: BartenderNPC = BartenderNPC.new()
	bartender.setup_staff(human, STAFF_NAMES["bartender"], BARTENDER_POSTS)
	bartender.station_point = BARTENDER_STATION
	_place_staff(bartender, BARTENDER_POSTS[0])

	var cook: CookNPC = CookNPC.new()
	cook.setup_staff(human, STAFF_NAMES["cook"], COOK_POSTS)
	cook.station_point = COOK_STATION
	_place_staff(cook, COOK_POSTS[0])

	var bouncer: BouncerNPC = BouncerNPC.new()
	bouncer.setup_staff(human, STAFF_NAMES["bouncer"], BOUNCER_POSTS)
	_place_staff(bouncer, BOUNCER_POSTS[0])

	var bard: BardNPC = BardNPC.new()
	bard.setup_staff(human, STAFF_NAMES["bard"], BARD_POSTS)
	_place_staff(bard, BARD_POSTS[0])


func _place_staff(staff: StaffNPC, at: Vector3) -> void:
	staff.position = at
	add_child(staff)
