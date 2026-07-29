class_name BouncerNPC
extends StaffNPC
## Keeps the peace: rushes active brawls and breaks them up.
##
## Subscribes to brawl events on the EventBus, walks to the fight, shouts
## the combatants down, and sends them out. Idles by the entrance.

const BREAKUP_DISTANCE: float = 1.8

var _target_a: PatronNPC = null
var _target_b: PatronNPC = null


func _init() -> void:
	role_title = "Bouncer"
	uniform_color = Color(0.2, 0.2, 0.24)
	wage_copper = 16


func _ready() -> void:
	super()
	EventBus.brawl_started.connect(_on_brawl_started)


func _on_brawl_started(initiator: PatronNPC, target: PatronNPC) -> void:
	if is_working:
		return
	_target_a = initiator
	_target_b = target


func _find_work() -> bool:
	if not _has_live_brawl():
		return false
	navigate_to(_brawl_point())
	return true


func _perform_work(_elapsed: float) -> void:
	if not _has_live_brawl():
		_clear_targets()
		stop_navigation()
		_finish_work()
		return
	if is_navigating():
		if global_position.distance_to(_brawl_point()) > BREAKUP_DISTANCE:
			return
		stop_navigation()
	say(DialogueLibrary.staff_line(DialogueLibrary.MOMENT_BREAKUP))
	if _is_fighting(_target_a):
		_target_a.break_up_fight()
	if _is_fighting(_target_b):
		_target_b.break_up_fight()
	_clear_targets()
	_finish_work()


func _has_live_brawl() -> bool:
	return _is_fighting(_target_a) or _is_fighting(_target_b)


func _is_fighting(patron: PatronNPC) -> bool:
	return (
		patron != null
		and is_instance_valid(patron)
		and patron.state == PatronNPC.State.FIGHTING
	)


func _brawl_point() -> Vector3:
	if _is_fighting(_target_a):
		return _target_a.global_position
	if _is_fighting(_target_b):
		return _target_b.global_position
	return global_position


func _clear_targets() -> void:
	_target_a = null
	_target_b = null
