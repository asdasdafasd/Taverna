class_name ServerStaff
extends StaffNPC
## Shared logic for staff who fulfill patron orders (bartender and cook).
##
## Listens for [signal EventBus.order_placed] events of the matching kind,
## queues them, prepares each at the work station, then carries the result
## to the patron's seat and delivers it.

enum TaskPhase {
	GOING_TO_STATION,
	PREPARING,
	DELIVERING,
}

## Fallback preparation time when an item has no recipe.
const DEFAULT_PREP_SECONDS: float = 4.0

## How close to the patron the server must get to hand the order over.
const DELIVERY_DISTANCE: float = 1.6

## The order kind this role fulfills; roles set it in _init.
var handled_kind: PatronOrder.Kind = PatronOrder.Kind.DRINK

## Where drinks/meals are prepared.
var station_point: Vector3 = Vector3.ZERO

var _order_queue: Array[PatronOrder] = []
var _current_order: PatronOrder = null
var _task_phase: TaskPhase = TaskPhase.GOING_TO_STATION
var _prep_seconds_left: float = 0.0


func _ready() -> void:
	super()
	EventBus.order_placed.connect(_on_order_placed)


func _on_order_placed(order: PatronOrder) -> void:
	if order.kind == handled_kind:
		_order_queue.append(order)


func _find_work() -> bool:
	while not _order_queue.is_empty():
		var candidate: PatronOrder = _order_queue[0]
		if not _order_valid(candidate):
			_order_queue.pop_front()
			continue
		_current_order = _order_queue.pop_front()
		_current_order.status = PatronOrder.Status.IN_PREPARATION
		_task_phase = TaskPhase.GOING_TO_STATION
		navigate_to(station_point)
		return true
	return false


func _perform_work(elapsed: float) -> void:
	if not _order_valid(_current_order):
		_abort_task()
		return
	match _task_phase:
		TaskPhase.GOING_TO_STATION:
			if not is_navigating():
				_task_phase = TaskPhase.PREPARING
				_prep_seconds_left = _prep_time_for(_current_order.item_id)
		TaskPhase.PREPARING:
			_prep_seconds_left -= elapsed
			if _prep_seconds_left <= 0.0:
				_task_phase = TaskPhase.DELIVERING
				navigate_to(_delivery_point())
		TaskPhase.DELIVERING:
			if not is_navigating():
				_deliver()


func _deliver() -> void:
	var patron: PatronNPC = _current_order.patron
	if _order_valid(_current_order) and (
		global_position.distance_to(patron.global_position) <= DELIVERY_DISTANCE * 2.0
	):
		face_point(patron.global_position)
		say(DialogueLibrary.staff_line(_serve_moment()))
		patron.receive_order(_current_order)
	_current_order = null
	_finish_work()


func _abort_task() -> void:
	_current_order = null
	stop_navigation()
	_finish_work()


func _order_valid(order: PatronOrder) -> bool:
	return (
		order != null
		and order.status != PatronOrder.Status.CANCELLED
		and order.patron != null
		and is_instance_valid(order.patron)
		and order.patron.state == PatronNPC.State.WAITING_ORDER
	)


func _delivery_point() -> Vector3:
	var patron: PatronNPC = _current_order.patron
	var toward_me: Vector3 = global_position - patron.global_position
	toward_me.y = 0.0
	if toward_me.length() < 0.1:
		toward_me = Vector3.FORWARD
	return patron.global_position + toward_me.normalized() * DELIVERY_DISTANCE * 0.6


func _prep_time_for(item_id: StringName) -> float:
	for recipe: RecipeData in GameManager.get_all_recipes():
		if recipe.output_item_id == item_id:
			# Real prep time is scaled down so service stays snappy in play.
			return clampf(recipe.prep_seconds * 0.2, 2.0, 12.0)
	return DEFAULT_PREP_SECONDS


func _serve_moment() -> String:
	if handled_kind == PatronOrder.Kind.DRINK:
		return DialogueLibrary.MOMENT_SERVE_DRINK
	return DialogueLibrary.MOMENT_SERVE_FOOD
