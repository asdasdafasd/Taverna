class_name StoryCharacterNPC
extends NPCBase
## A named recurring character: stands at an anchor point, offers ambient
## lines, and opens staged dialogue when the player talks to them.
##
## Spawned and despawned by [StoryDirector] according to story state. The
## dialogue content lives in [code]data/dialogue/story_dialogue.json[/code];
## which stage plays is decided by [StoryDialogue] from flags and quests.

## Seconds between ambient bubble lines while idle.
const AMBIENT_LINE_INTERVAL_MIN: float = 18.0
const AMBIENT_LINE_INTERVAL_MAX: float = 34.0

const TALK_ZONE_SCENE: PackedScene = preload("res://npc/story/talk_zone.tscn")

## Stable id used by quests and dialogue data ("maren", "fenwick", "vess").
var character_id: StringName = &""

## Tint that makes the character read as unique in the room.
var signature_color: Color = Color(0.6, 0.5, 0.4)

var _ambient_seconds_left: float = 0.0


## Must be called before adding to the tree.
func setup_character(
	id: StringName, display_name: String, body_race: RaceData, tint: Color
) -> void:
	character_id = id
	npc_name = display_name
	race = body_race
	signature_color = tint


func _ready() -> void:
	super()
	name = "Story_%s" % character_id
	set_body_tint(signature_color)
	var talk_zone: TalkInteraction = TALK_ZONE_SCENE.instantiate() as TalkInteraction
	add_child(talk_zone)
	_ambient_seconds_left = randf_range(
		AMBIENT_LINE_INTERVAL_MIN, AMBIENT_LINE_INTERVAL_MAX
	)


func _think(elapsed: float) -> void:
	_ambient_seconds_left -= elapsed
	if _ambient_seconds_left > 0.0:
		return
	_ambient_seconds_left = randf_range(
		AMBIENT_LINE_INTERVAL_MIN, AMBIENT_LINE_INTERVAL_MAX
	)
	var line: String = StoryDialogue.ambient_line(character_id)
	if not line.is_empty():
		say(line)


## Opens the staged conversation in the dialogue panel.
func begin_conversation(actor: Node3D) -> void:
	face_point(actor.global_position)
	DialoguePanel.instance_open(self)
