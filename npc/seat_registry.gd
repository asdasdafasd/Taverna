class_name SeatRegistry
extends RefCounted
## Query helpers over all [Seat] nodes currently in the scene tree.
##
## Stateless: seats own their occupancy, the registry only searches. All
## functions take the calling node so they can reach the scene tree without
## a global reference.


## All seats in the scene, free or not.
static func all_seats(from_node: Node) -> Array[Seat]:
	var seats: Array[Seat] = []
	for node: Node in from_node.get_tree().get_nodes_in_group(Seat.SEAT_GROUP):
		var seat: Seat = node as Seat
		if seat != null:
			seats.append(seat)
	return seats


## All currently unclaimed seats.
static func free_seats(from_node: Node) -> Array[Seat]:
	var seats: Array[Seat] = []
	for seat: Seat in all_seats(from_node):
		if seat.is_free():
			seats.append(seat)
	return seats


## The free seat closest to [param origin], or null when everything is taken.
static func closest_free_seat(from_node: Node, origin: Vector3) -> Seat:
	var best: Seat = null
	var best_distance: float = INF
	for seat: Seat in free_seats(from_node):
		var distance: float = origin.distance_squared_to(seat.global_position)
		if distance < best_distance:
			best_distance = distance
			best = seat
	return best


## The free seat with the fewest neighbors within [param radius] meters.
## Distance to [param origin] breaks ties, so aloof races still pick
## reachable seats. Returns null when no seat is free.
static func most_isolated_free_seat(
	from_node: Node, origin: Vector3, radius: float
) -> Seat:
	var seats: Array[Seat] = all_seats(from_node)
	var best: Seat = null
	var best_neighbors: int = 0x7FFFFFFF
	var best_distance: float = INF
	var radius_squared: float = radius * radius
	for seat: Seat in seats:
		if not seat.is_free():
			continue
		var neighbors: int = 0
		for other: Seat in seats:
			if other == seat or other.is_free():
				continue
			if seat.global_position.distance_squared_to(other.global_position) <= radius_squared:
				neighbors += 1
		var distance: float = origin.distance_squared_to(seat.global_position)
		if neighbors < best_neighbors or (
			neighbors == best_neighbors and distance < best_distance
		):
			best_neighbors = neighbors
			best_distance = distance
			best = seat
	return best


## Occupied seats within [param radius] meters of [param seat], excluding it.
static func occupied_neighbors(
	from_node: Node, seat: Seat, radius: float
) -> Array[Seat]:
	var neighbors: Array[Seat] = []
	var radius_squared: float = radius * radius
	for other: Seat in all_seats(from_node):
		if other == seat or other.is_free():
			continue
		if seat.global_position.distance_squared_to(other.global_position) <= radius_squared:
			neighbors.append(other)
	return neighbors
