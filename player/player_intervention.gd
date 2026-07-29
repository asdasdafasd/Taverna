class_name PlayerIntervention
extends Node
## The keeper's two ways to handle a brawl in person.
##
## SHOVE ([code]F[/code]): step in bodily — instantly breaks up the nearest
## fight within reach, but the rough handling nudges tension up.
## SOOTHE ([code]G[/code]): stand a round of drinks on the house — costs
## coin, vents tension, and has a good chance of ending the fight with both
## patrons returning to their seats.

const INTERVENTION_RANGE: float = 3.5
const SHOVE_TENSION_COST: float = 4.0
const SOOTHE_COST_COPPER: int = 8

var _player: PlayerController = null


func _ready() -> void:
	_player = get_parent() as PlayerController
	assert(_player != null, "PlayerIntervention must be a child of PlayerController")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shove"):
		_try_shove()
	elif event.is_action_pressed("soothe"):
		_try_soothe()


func _try_shove() -> void:
	if not _brawl_in_range():
		EventBus.post_notification("No brawl within reach to break up.")
		return
	if BrawlManager.break_up_nearest(_player.global_position):
		TensionManager.add_tension(SHOVE_TENSION_COST)
		EventBus.post_notification("You shove the brawlers apart. Out. Now.")


func _try_soothe() -> void:
	if not _brawl_in_range():
		EventBus.post_notification("Nobody nearby needs soothing right now.")
		return
	if not EconomyManager.try_spend(
		SOOTHE_COST_COPPER, EconomyManager.Category.HOSPITALITY, "a round on the house"
	):
		EventBus.post_notification("You cannot afford a round on the house.")
		return
	if BrawlManager.try_calm_nearest(_player.global_position):
		EventBus.post_notification("A round on the house settles the matter.")
	else:
		EventBus.post_notification("The drinks help the room, but not the fight.")


func _brawl_in_range() -> bool:
	for fighter: PatronNPC in BrawlManager.active_fighters():
		if fighter.state != PatronNPC.State.FIGHTING:
			continue
		var distance: float = _player.global_position.distance_to(
			fighter.global_position
		)
		if distance <= INTERVENTION_RANGE:
			return true
	return false
