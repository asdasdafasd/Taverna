class_name StoryDirector
extends Node3D
## Decides which recurring story characters are present in the tavern.
##
## Presence is re-evaluated every in-game hour and when story flags change:
## Old Fenwick holds his stool most evenings, Maren the courier calls in
## daylight when she has something for the keeper, and Vess only appears in
## the small hours once the story has led the player to her. Also places
## the Accord Stone in the cellar once Fenwick has revealed it.

const ACCORD_STONE_SCENE: PackedScene = preload(
	"res://world/props/accord_stone.tscn"
)

## Anchor spots (world space) for each character.
const FENWICK_SPOT: Vector3 = Vector3(-4.9, 0.05, -1.6)
const MAREN_SPOT: Vector3 = Vector3(0.9, 0.05, 1.1)
const VESS_SPOT: Vector3 = Vector3(-6.0, 0.05, 3.6)

## Cellar placement for the Accord Stone (against the north wall).
const STONE_POSITION: Vector3 = Vector3(-4.0, -3.0, -9.2)

## Presence windows (24h clock).
const FENWICK_FROM_HOUR: int = 16
const FENWICK_TO_HOUR: int = 1
const MAREN_FROM_HOUR: int = 9
const MAREN_TO_HOUR: int = 19
const VESS_FROM_HOUR: int = 22
const VESS_TO_HOUR: int = 3

var _characters: Dictionary[StringName, StoryCharacterNPC] = {}
var _stone: Node3D = null


func _ready() -> void:
	TimeManager.hour_passed.connect(_on_hour_passed)
	StoryManager.flag_raised.connect(_on_flag_raised)
	EventBus.navigation_ready.connect(_refresh_presence)


func _on_hour_passed(_day: int, _hour: int) -> void:
	_refresh_presence()


func _on_flag_raised(_flag: StringName) -> void:
	_refresh_presence()


func _refresh_presence() -> void:
	_sync_character(
		&"fenwick", "Old Fenwick", &"dwarf",
		Color(0.5, 0.36, 0.24), FENWICK_SPOT,
		_should_fenwick_be_here()
	)
	_sync_character(
		&"maren", "Maren the Courier", &"human",
		Color(0.35, 0.42, 0.55), MAREN_SPOT,
		_should_maren_be_here()
	)
	_sync_character(
		&"vess", "Vess", &"undead",
		Color(0.72, 0.78, 0.82), VESS_SPOT,
		_should_vess_be_here()
	)
	_sync_stone()


func _should_fenwick_be_here() -> bool:
	# The regular: on his stool every evening into the small hours.
	return _hour_in_window(FENWICK_FROM_HOUR, FENWICK_TO_HOUR)


func _should_maren_be_here() -> bool:
	if not _hour_in_window(MAREN_FROM_HOUR, MAREN_TO_HOUR):
		return false
	# She calls whenever a quest needs her, and drops by otherwise too.
	if QuestManager.is_quest_active(&"meet_the_courier"):
		return true
	if QuestManager.is_quest_active(&"letters_from_aldous"):
		return true
	return StoryManager.has_flag(&"aldous_truth")


func _should_vess_be_here() -> bool:
	if not _hour_in_window(VESS_FROM_HOUR, VESS_TO_HOUR):
		return false
	if QuestManager.is_quest_active(&"the_pale_guest"):
		return true
	if QuestManager.is_quest_active(&"the_accord_choice"):
		return true
	return StoryManager.has_flag(&"accord_choice_made")


func _sync_character(
	id: StringName, display_name: String, race_id: StringName,
	tint: Color, spot: Vector3, should_exist: bool
) -> void:
	var existing: StoryCharacterNPC = _characters.get(id)
	var alive: bool = existing != null and is_instance_valid(existing)
	if should_exist and not alive:
		var race: RaceData = GameManager.get_race(race_id)
		if race == null:
			return
		var character: StoryCharacterNPC = StoryCharacterNPC.new()
		character.setup_character(id, display_name, race, tint)
		character.position = spot
		add_child(character)
		_characters[id] = character
	elif not should_exist and alive:
		existing.queue_free()
		_characters.erase(id)


func _sync_stone() -> void:
	var should_exist: bool = StoryManager.has_flag(&"heard_of_accord")
	var alive: bool = _stone != null and is_instance_valid(_stone)
	if should_exist and not alive:
		_stone = ACCORD_STONE_SCENE.instantiate() as Node3D
		_stone.position = STONE_POSITION
		add_child(_stone)
	elif not should_exist and alive:
		_stone.queue_free()
		_stone = null


func _hour_in_window(from_hour: int, to_hour: int) -> bool:
	var hour: int = TimeManager.hour
	if from_hour <= to_hour:
		return hour >= from_hour and hour <= to_hour
	return hour >= from_hour or hour <= to_hour
