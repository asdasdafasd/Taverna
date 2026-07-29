class_name CarryableProp
extends Interactable
## An interactable rigid-body prop the player can pick up, carry, and drop.
##
## Attach to a [RigidBody3D] on the "interactable" and "carryable" physics
## layers. While carried the body is frozen and glides toward the player's
## carry anchor; on drop it re-enters simulation with a gentle toss impulse.

## How strongly the carried body homes toward the carry anchor (per second).
const FOLLOW_DECAY: float = 14.0

## Forward toss speed applied on drop, in meters per second.
const DROP_TOSS_SPEED: float = 1.5

## Optional catalog id linking this prop to an [ItemData] definition.
@export var item_id: StringName = &""

var is_carried: bool = false

var _body: RigidBody3D = null
var _carry_anchor: Node3D = null
var _original_layer: int = 0


func _ready() -> void:
	super()
	_body = self as RigidBody3D
	assert(_body != null, "CarryableProp must be attached to a RigidBody3D")
	_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_original_layer = _body.collision_layer


func _physics_process(delta: float) -> void:
	if not is_carried or _carry_anchor == null:
		return
	var target: Transform3D = _carry_anchor.global_transform
	global_position = MathUtils.exp_decay_v3(
		global_position, target.origin, FOLLOW_DECAY, delta
	)
	global_basis = global_basis.slerp(target.basis, 1.0 - exp(-FOLLOW_DECAY * delta))


## Picking up is the default interaction for carryable props.
func interact(actor: Node3D) -> void:
	var carrier: PlayerController = actor as PlayerController
	if carrier == null:
		return
	carrier.request_carry(self)


## Called by the carrier to attach this prop to [param anchor].
func begin_carry(anchor: Node3D) -> void:
	if is_carried:
		return
	is_carried = true
	_carry_anchor = anchor
	_body.freeze = true
	_body.collision_layer = 0
	_body.linear_velocity = Vector3.ZERO
	_body.angular_velocity = Vector3.ZERO
	enabled = false
	EventBus.carry_state_changed.emit(self, true)


## Called by the carrier to release the prop with a light forward toss.
func end_carry(toss_direction: Vector3) -> void:
	if not is_carried:
		return
	is_carried = false
	_carry_anchor = null
	_body.collision_layer = _original_layer
	_body.freeze = false
	_body.linear_velocity = toss_direction.normalized() * DROP_TOSS_SPEED
	enabled = true
	EventBus.carry_state_changed.emit(self, false)
