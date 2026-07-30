class_name StoryMarker
extends Interactable
## A world object the player examines to advance the story.
##
## Emits [signal EventBus.story_marker_activated] with its
## [member marker_id] and shows its found-text once; afterwards it stays
## examinable with a shorter reminder line.

## Id quests listen for (e.g. "accord_stone").
@export var marker_id: StringName = &""

## Notification shown the first time the marker is examined.
@export_multiline var found_text: String = ""

## Notification for repeat examinations.
@export_multiline var repeat_text: String = ""

var _found: bool = false


func interact(_actor: Node3D) -> void:
	if _found:
		if not repeat_text.is_empty():
			EventBus.post_notification(repeat_text)
		return
	_found = true
	if not found_text.is_empty():
		EventBus.post_notification(found_text)
	EventBus.story_marker_activated.emit(marker_id)
