class_name StaffNPC
extends NPCBase
## Base class for tavern employees (bartender, cook, bouncer, bard).
##
## Staff prioritize work tasks over personal behavior: each think tick they
## first look for role work via [method _find_work]; only when idle do they
## wander between their assigned duty posts and mutter idle lines. Roles
## override [method _find_work] and [method _perform_work].

## Emitted when the staff member starts or finishes a work task.
signal work_state_changed(is_working: bool)

const IDLE_LINE_CHANCE: float = 0.04
const POST_WANDER_CHANCE: float = 0.25

## Player-facing role title, e.g. "Bartender".
var role_title: String = ""

## Uniform tint applied to the body so staff read differently from patrons.
var uniform_color: Color = Color(0.5, 0.45, 0.4)

## Where this staff member stands while idle; roles set these in setup.
var duty_posts: Array[Vector3] = []

var is_working: bool = false

var _current_post_index: int = 0


## Configures identity and duty posts; call before adding to the tree.
func setup_staff(
	staff_race: RaceData, staff_name: String, posts: Array[Vector3]
) -> void:
	race = staff_race
	npc_name = staff_name
	duty_posts = posts


func _ready() -> void:
	super()
	name = "Staff_%s_%s" % [role_title, npc_name]
	set_body_tint(uniform_color)
	if not duty_posts.is_empty():
		global_position = duty_posts[0]


func _think(elapsed: float) -> void:
	# Priority 1: role work.
	if is_working:
		_perform_work(elapsed)
		return
	if _find_work():
		_set_working(true)
		return
	# Priority 2: idle presence at duty posts.
	_idle_behavior()


## Override point: returns true when a work task was claimed this tick.
func _find_work() -> bool:
	return false


## Override point: advances the active task; call [method _finish_work] when done.
func _perform_work(_elapsed: float) -> void:
	_finish_work()


func _finish_work() -> void:
	_set_working(false)


func _idle_behavior() -> void:
	if duty_posts.is_empty() or is_navigating():
		return
	if randf() < POST_WANDER_CHANCE and duty_posts.size() > 1:
		_current_post_index = (_current_post_index + 1) % duty_posts.size()
		navigate_to(duty_posts[_current_post_index])
	elif randf() < IDLE_LINE_CHANCE:
		say(DialogueLibrary.staff_line(DialogueLibrary.MOMENT_WORK_IDLE))


func _set_working(working: bool) -> void:
	if is_working == working:
		return
	is_working = working
	work_state_changed.emit(is_working)
