class_name BardNPC
extends StaffNPC
## Performs song verses from a stage spot, lifting the mood of seated patrons.
##
## The bard's "work" is a recurring performance: a verse every so often,
## with a small mood bonus rippling out to everyone seated in the room.

const VERSE_INTERVAL_MIN: float = 14.0
const VERSE_INTERVAL_MAX: float = 26.0
const PERFORM_MOOD_BONUS: float = 0.04

var _seconds_until_verse: float = 0.0


func _init() -> void:
	role_title = "Bard"
	uniform_color = Color(0.5, 0.24, 0.42)
	wage_copper = 10
	_seconds_until_verse = randf_range(VERSE_INTERVAL_MIN, VERSE_INTERVAL_MAX)


func _find_work() -> bool:
	# Performing is continuous: the bard is always "working" once in place.
	return not is_navigating()


func _perform_work(elapsed: float) -> void:
	_seconds_until_verse -= elapsed
	if _seconds_until_verse > 0.0:
		return
	_seconds_until_verse = randf_range(VERSE_INTERVAL_MIN, VERSE_INTERVAL_MAX)
	say(DialogueLibrary.staff_line(DialogueLibrary.MOMENT_PERFORM))
	for seat: Seat in SeatRegistry.all_seats(self):
		var listener: PatronNPC = seat.occupant as PatronNPC
		if listener != null and is_instance_valid(listener) and listener.is_sitting:
			listener.mood = clampf(
				listener.mood + PERFORM_MOOD_BONUS, 0.0, 1.0
			)
	_finish_work()
