class_name InteractionRay
extends RayCast3D
## Camera-centered ray that focuses and activates [Interactable] objects.
##
## Lives under the player's camera, pointing forward. Tracks the currently
## focused interactable, drives its highlight, and broadcasts focus changes
## on the [EventBus] so the HUD can show prompts.

## Maximum interaction reach in meters.
const REACH_METERS: float = 2.6

## Physics layers the ray scans: world (1) blocks, interactable (3) focuses.
const RAY_COLLISION_MASK: int = 0b101

var focused: Interactable = null


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -REACH_METERS)
	collision_mask = RAY_COLLISION_MASK
	collide_with_areas = true
	collide_with_bodies = true


## Extends the ray so third-person reach stays constant: the camera sits
## [param extra] meters behind the player, so the ray must cover that too.
func set_extra_reach(extra: float) -> void:
	target_position = Vector3(0.0, 0.0, -(REACH_METERS + maxf(0.0, extra)))


func _physics_process(_delta: float) -> void:
	var hit: Interactable = null
	if enabled and is_colliding():
		hit = get_collider() as Interactable
		if hit != null and not hit.enabled:
			hit = null
	_set_focused(hit)


## Activates the focused interactable on behalf of [param actor].
## Returns true when something handled the interaction.
func interact(actor: Node3D) -> bool:
	if focused == null:
		return false
	return focused.try_interact(actor)


## Clears focus (used when the player starts carrying something).
func clear_focus() -> void:
	_set_focused(null)


func _set_focused(interactable: Interactable) -> void:
	if focused == interactable:
		return
	if focused != null and is_instance_valid(focused):
		focused.set_focused(false)
	focused = interactable
	if focused != null:
		focused.set_focused(true)
	EventBus.interaction_focus_changed.emit(focused)
