class_name TavernDoor
extends Interactable
## A hinged door the player can open and close.
##
## Attach to a [StaticBody3D] whose origin sits on the hinge edge.
## Interacting tweens the yaw between the closed scene rotation and
## closed + [member open_angle_degrees].

## Emitted after the door starts swinging toward a new state.
signal state_toggled(is_open: bool)

## Seconds the door stays open after the last NPC clears the doorway.
const AUTO_CLOSE_DELAY: float = 1.2

## Size of the NPC detection volume straddling the doorway.
const SENSOR_SIZE: Vector3 = Vector3(2.4, 2.2, 2.6)

## Physics layer bit used by NPC bodies.
const NPC_LAYER_MASK: int = 0b10000

## Yaw offset applied when open, in degrees. Sign controls swing direction.
@export_range(-160.0, 160.0, 1.0) var open_angle_degrees: float = 100.0

## Seconds the swing animation takes.
@export_range(0.1, 2.0, 0.05) var swing_seconds: float = 0.6

var is_open: bool = false

var _closed_yaw: float = 0.0
var _swing_tween: Tween = null
var _npc_sensor: Area3D = null
var _npcs_in_doorway: int = 0
var _auto_opened: bool = false
var _auto_close_timer: Timer = null


func _ready() -> void:
	super()
	_closed_yaw = rotation.y
	_build_npc_sensor()


func get_prompt_text() -> String:
	var verb: String = "Close" if is_open else "Open"
	return "%s — %s" % [verb, display_name]


func interact(_actor: Node3D) -> void:
	# A deliberate player toggle overrides any pending auto-close.
	_auto_opened = false
	_auto_close_timer.stop()
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


# --- NPC auto-opening ---------------------------------------------------------


func _build_npc_sensor() -> void:
	_npc_sensor = Area3D.new()
	_npc_sensor.name = "NpcSensor"
	_npc_sensor.collision_layer = 0
	_npc_sensor.collision_mask = NPC_LAYER_MASK
	_npc_sensor.monitorable = false
	# Keep the sensor in world space so it does not swing with the panel
	# and always covers both sides of the doorway.
	_npc_sensor.top_level = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "SensorShape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = SENSOR_SIZE
	shape.shape = box
	# Center the sensor on the doorway (half the panel width from the hinge).
	shape.position = Vector3(0.675, SENSOR_SIZE.y * 0.5, 0.0)
	_npc_sensor.add_child(shape)
	add_child(_npc_sensor)
	_npc_sensor.global_transform = global_transform
	_npc_sensor.body_entered.connect(_on_npc_body_entered)
	_npc_sensor.body_exited.connect(_on_npc_body_exited)

	_auto_close_timer = Timer.new()
	_auto_close_timer.name = "AutoCloseTimer"
	_auto_close_timer.one_shot = true
	_auto_close_timer.wait_time = AUTO_CLOSE_DELAY
	add_child(_auto_close_timer)
	_auto_close_timer.timeout.connect(_on_auto_close_timeout)


func _on_npc_body_entered(_body: Node3D) -> void:
	_npcs_in_doorway += 1
	_auto_close_timer.stop()
	if not is_open:
		_auto_opened = true
		toggle()


func _on_npc_body_exited(_body: Node3D) -> void:
	_npcs_in_doorway = maxi(0, _npcs_in_doorway - 1)
	if _npcs_in_doorway == 0 and _auto_opened:
		_auto_close_timer.start()


func _on_auto_close_timeout() -> void:
	if _npcs_in_doorway == 0 and _auto_opened and is_open:
		_auto_opened = false
		toggle()
