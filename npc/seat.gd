class_name Seat
extends Node3D
## A claimable sitting spot attached to a stool or bench.
##
## NPCs claim a seat before walking to it; a claimed seat refuses all other
## claimants until released, which makes double-seating impossible. Seats
## register themselves in the [constant SEAT_GROUP] group so [SeatRegistry]
## can find them without scene coupling.

## Emitted when the seat is claimed or released.
signal occupancy_changed(seat: Seat, occupant: NPCBase)

## Group used by [SeatRegistry] to discover all seats in the scene.
const SEAT_GROUP: StringName = &"seats"

## Group joined by tables/counters that seats should face when occupied.
const FOCUS_GROUP: StringName = &"seat_focus"

## Maximum distance to a focus target for auto-facing, in meters.
const FOCUS_RANGE: float = 2.5

## Where the sitter's body rests, relative to this node.
const SIT_HEIGHT: float = 0.5

## The NPC currently holding this seat (claimed or seated), or null.
var occupant: NPCBase = null

var _sit_yaw: float = 0.0


func _ready() -> void:
	add_to_group(SEAT_GROUP)
	_sit_yaw = global_rotation.y
	_face_nearest_focus.call_deferred()


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)


## Attempts to claim the seat for [param claimant].
## Returns false when another NPC already holds it.
func try_claim(claimant: NPCBase) -> bool:
	if not is_free():
		return occupant == claimant
	occupant = claimant
	occupancy_changed.emit(self, occupant)
	return true


## Releases the seat if [param holder] is the current occupant.
func release(holder: NPCBase) -> void:
	if occupant != holder:
		return
	occupant = null
	occupancy_changed.emit(self, null)


## World position an NPC should stand at to sit down here.
func stand_point() -> Vector3:
	return global_position


## World position of the sitter's pelvis when seated.
func sit_point() -> Vector3:
	return global_position + Vector3(0.0, SIT_HEIGHT, 0.0)


## Yaw the sitter should face while seated (toward the nearest table).
func sit_yaw() -> float:
	return _sit_yaw


func _face_nearest_focus() -> void:
	var best: Node3D = null
	var best_distance: float = FOCUS_RANGE * FOCUS_RANGE
	for node: Node in get_tree().get_nodes_in_group(FOCUS_GROUP):
		var target: Node3D = node as Node3D
		if target == null:
			continue
		var distance: float = global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	if best == null:
		return
	var toward: Vector3 = best.global_position - global_position
	toward.y = 0.0
	if toward.length() > 0.05:
		_sit_yaw = atan2(-toward.x, -toward.z)
