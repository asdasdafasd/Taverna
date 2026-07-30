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

## Emitted once the tavern's navigation mesh has finished baking.
signal navigation_ready

## Emitted when a patron steps into the tavern proper.
signal patron_entered(patron: PatronNPC)

## Emitted after a patron claims and reaches a seat.
signal patron_seated(patron: PatronNPC, seat: Seat)

## Emitted when a patron despawns at the exit.
signal patron_left(patron: PatronNPC)

## Emitted when a patron places an order for staff to fulfill.
signal order_placed(order: PatronOrder)

## Emitted when staff hands the finished order to the patron.
signal order_delivered(order: PatronOrder)

## Emitted when a patron settles their bill (tips included).
signal patron_paid(patron: PatronNPC, copper_amount: int)

## Emitted when two patrons start brawling.
signal brawl_started(initiator: PatronNPC, target: PatronNPC)

## Emitted when a brawl finishes or is broken up.
signal brawl_ended(initiator: PatronNPC, target: PatronNPC)

## Emitted whenever an NPC says a line out loud (speech bubble shown).
signal npc_spoke(npc: NPCBase, text: String)

## Emitted when a brawl is resolved peacefully (calming intervention).
signal brawl_calmed(fighter: PatronNPC)

## Emitted after accumulated furniture damage is paid off.
signal furniture_repaired

## Emitted after a successful stock purchase.
signal item_restocked(item_id: StringName)

## Emitted when a story flag is raised for the first time.
signal story_flag_set(flag: StringName)

## Emitted after the player finishes a conversation with a story character.
signal story_character_talked(character_id: StringName)

## Emitted when the player activates a story marker in the world.
signal story_marker_activated(marker_id: StringName)


## Convenience helper so callers do not need to reference the signal directly.
func post_notification(text: String) -> void:
	notification_posted.emit(text)
