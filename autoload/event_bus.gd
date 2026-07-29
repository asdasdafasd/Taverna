extends Node
## Global signal hub for decoupled cross-system communication.
##
## Systems emit and subscribe here instead of holding hard references to each
## other. Keep this class free of state and logic: it is a wiring surface only.
## Autoload name: [code]EventBus[/code].

## Emitted when the interaction ray focuses a new object.
## [param interactable] is [code]null[/code] when focus is cleared.
signal interaction_focus_changed(interactable: Interactable)

## Emitted after an interactable has been successfully activated.
signal interaction_performed(interactable: Interactable, actor: Node3D)

## Emitted when a prop is picked up ([param is_carried] = true) or released.
signal carry_state_changed(prop: CarryableProp, is_carried: bool)

## Emitted when the player switches between first and third person.
signal camera_view_changed(first_person: bool)

## Emitted after a save file has been written to disk.
signal game_saved(path: String)

## Emitted after a save file has been read and applied.
signal game_loaded(path: String)

## Emitted when any system wants to show a short on-screen toast message.
signal notification_posted(text: String)


## Convenience helper so callers do not need to reference the signal directly.
func post_notification(text: String) -> void:
	notification_posted.emit(text)
