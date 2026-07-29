class_name TavernDoor
extends Interactable
## A hinged door the player can open and close.
##
## Attach to a [StaticBody3D] whose origin sits on the hinge edge.
## Interacting tweens the yaw between the closed scene rotation and
## closed + [member open_angle_degrees].

## Emitted after the door starts swinging toward a new state.
signal state_toggled(is_open: bool)

## Yaw offset applied when open, in degrees. Sign controls swing direction.
@export_range(-160.0, 160.0, 1.0) var open_angle_degrees: float = 100.0

## Seconds the swing animation takes.
@export_range(0.1, 2.0, 0.05) var swing_seconds: float = 0.6

var is_open: bool = false

var _closed_yaw: float = 0.0
var _swing_tween: Tween = null


func _ready() -> void:
	super()
	_closed_yaw = rotation.y


func get_prompt_text() -> String:
	var verb: String = "Close" if is_open else "Open"
	return "%s — %s" % [verb, display_name]


func interact(_actor: Node3D) -> void:
	toggle()


## Swings the door to the opposite state.
func toggle() -> void:
	is_open = not is_open
	var target_yaw: float = _closed_yaw
	if is_open:
		target_yaw += deg_to_rad(open_angle_degrees)
	if _swing_tween != null:
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_swing_tween.tween_property(self, "rotation:y", target_yaw, swing_seconds)
	state_toggled.emit(is_open)
