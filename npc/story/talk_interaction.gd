class_name TalkInteraction
extends Interactable
## Focusable talk zone attached to a story character.
##
## An [Area3D] child of [StoryCharacterNPC] on the "interactable" layer so
## the player's interaction ray can focus the character; interacting opens
## the dialogue panel through the character.

var _character: StoryCharacterNPC = null


func _ready() -> void:
	_character = get_parent() as StoryCharacterNPC
	assert(_character != null, "TalkInteraction requires a StoryCharacterNPC parent")
	prompt_verb = "Talk"
	display_name = _character.npc_name
	# Highlight the character's body meshes rather than this empty area.
	_collect_highlight_meshes(_character)
	super()


func interact(actor: Node3D) -> void:
	_character.begin_conversation(actor)
