class_name NPCBase
extends CharacterBody3D
## Shared foundation for all tavern NPCs (patrons and staff).
##
## Owns navigation-driven locomotion, the procedurally tinted body, speech
## bubble output, and a lightweight timer-driven "think" loop. Subclasses
## implement [method _think] for decisions and react to
## [method _on_navigation_arrived] for movement completion. Per-frame code is
## limited to steering; all decision making happens on the think timer.

## Emitted when the NPC reaches its current navigation target.
signal arrived

## Seconds between think-loop evaluations (randomly jittered per NPC so
## crowds do not evaluate on the same frame).
const THINK_INTERVAL_MIN: float = 0.4
const THINK_INTERVAL_MAX: float = 0.7

const GRAVITY: float = 21.0
const STEER_DECAY: float = 10.0
const TURN_DECAY: float = 9.0
const ARRIVAL_DISTANCE: float = 0.45
const BODY_RADIUS: float = 0.3
const BODY_HEIGHT: float = 1.7
const HEAD_RADIUS: float = 0.17
const SPEECH_HEIGHT_MARGIN: float = 0.45
const AVOIDANCE_RADIUS: float = 0.4
const NAV_SAMPLE_MAX_DISTANCE: float = 2.0

## Movement profile and identity, set by the spawner before add_child.
var race: RaceData = null

## Display name, generated from race name pools.
var npc_name: String = ""

## True while the NPC is parked on a seat (locomotion suspended).
var is_sitting: bool = false

var _navigation_agent: NavigationAgent3D = null
var _speech_bubble: SpeechBubble = null
var _think_timer: Timer = null
var _body_mesh: MeshInstance3D = null
var _head_mesh: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _body_material: StandardMaterial3D = null
var _has_navigation_target: bool = false
var _arrival_pending: bool = false
var _safe_velocity: Vector3 = Vector3.ZERO
var _last_think_ms: int = 0
var _pre_sit_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 0b10000
	collision_mask = 0b1
	_build_body()
	_build_navigation_agent()
	_build_speech_bubble()
	_build_think_timer()


func _physics_process(delta: float) -> void:
	if is_sitting:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var desired_velocity: Vector3 = Vector3.ZERO
	if _has_navigation_target and not _navigation_agent.is_navigation_finished():
		var next_point: Vector3 = _navigation_agent.get_next_path_position()
		var direction: Vector3 = next_point - global_position
		direction.y = 0.0
		if direction.length() > 0.01:
			desired_velocity = direction.normalized() * move_speed()
			_face_direction(direction, delta)
	# Feed the avoidance simulation; _safe_velocity arrives via callback.
	_navigation_agent.velocity = desired_velocity
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = MathUtils.exp_decay_v3(horizontal, _safe_velocity, STEER_DECAY, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	if _has_navigation_target and _navigation_agent.is_navigation_finished():
		_finish_navigation()


## Meters per second; subclasses may modulate (e.g. angry patrons stride).
func move_speed() -> float:
	if race != null:
		return race.walk_speed
	return 2.0


## Starts walking toward [param world_position] along the navmesh.
func navigate_to(world_position: Vector3) -> void:
	_has_navigation_target = true
	_arrival_pending = true
	_navigation_agent.target_position = world_position


## Stops all pathing immediately.
func stop_navigation() -> void:
	_has_navigation_target = false
	_arrival_pending = false
	_safe_velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0


## True while a navigation target is active and unreached.
func is_navigating() -> bool:
	return _has_navigation_target


## Says [param line] in a speech bubble and announces it on the EventBus.
func say(line: String) -> void:
	if line.is_empty():
		return
	_speech_bubble.show_line(line)
	EventBus.npc_spoke.emit(self, line)


## Parks the NPC on a seat: disables locomotion and poses at the sit point.
## The pre-sit position is remembered so standing up never clips furniture.
func sit_at(seat: Seat) -> void:
	_pre_sit_position = global_position
	is_sitting = true
	stop_navigation()
	global_position = seat.stand_point()
	rotation.y = seat.sit_yaw()
	_pose_sitting(true)


## Returns the NPC to standing locomotion at the remembered approach point.
func stand_up() -> void:
	if not is_sitting:
		return
	is_sitting = false
	_pose_sitting(false)
	global_position = _pre_sit_position


## Instantly turns the NPC to face [param world_point].
func face_point(world_point: Vector3) -> void:
	var flat: Vector3 = world_point - global_position
	flat.y = 0.0
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)


## Recolors the body (staff roles use this for uniform identity).
func set_body_tint(color: Color) -> void:
	if _body_material != null:
		_body_material.albedo_color = color


## Override point: subclass decision logic, called on the think timer.
## [param _elapsed] is the real seconds since the previous think tick.
func _think(_elapsed: float) -> void:
	pass


## Override point: called once when the active navigation target is reached.
func _on_navigation_arrived() -> void:
	pass


# --- Construction -----------------------------------------------------------


func _build_body() -> void:
	var body_color: Color = race.body_color if race != null else Color(0.7, 0.6, 0.5)
	var height_scale: float = race.height_scale if race != null else 1.0
	var body_height: float = BODY_HEIGHT * height_scale

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = body_color
	material.roughness = 0.85
	_body_material = material

	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = BODY_RADIUS * (0.8 + 0.2 * height_scale)
	torso.height = body_height - HEAD_RADIUS * 2.0
	torso.material = material
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Torso"
	_body_mesh.mesh = torso
	_body_mesh.position.y = torso.height * 0.5
	add_child(_body_mesh)

	var head: SphereMesh = SphereMesh.new()
	head.radius = HEAD_RADIUS * (0.85 + 0.15 * height_scale)
	head.height = head.radius * 2.0
	head.material = material
	_head_mesh = MeshInstance3D.new()
	_head_mesh.name = "Head"
	_head_mesh.mesh = head
	_head_mesh.position.y = body_height - head.radius
	add_child(_head_mesh)

	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = body_height
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "BodyShape"
	_collision_shape.shape = capsule
	_collision_shape.position.y = body_height * 0.5
	add_child(_collision_shape)


func _build_navigation_agent() -> void:
	_navigation_agent = NavigationAgent3D.new()
	_navigation_agent.name = "NavigationAgent"
	_navigation_agent.radius = AVOIDANCE_RADIUS
	_navigation_agent.path_desired_distance = ARRIVAL_DISTANCE
	_navigation_agent.target_desired_distance = ARRIVAL_DISTANCE
	_navigation_agent.path_max_distance = NAV_SAMPLE_MAX_DISTANCE
	_navigation_agent.avoidance_enabled = true
	_navigation_agent.max_speed = move_speed()
	add_child(_navigation_agent)
	_navigation_agent.velocity_computed.connect(_on_avoidance_velocity)


func _build_speech_bubble() -> void:
	var height_scale: float = race.height_scale if race != null else 1.0
	_speech_bubble = SpeechBubble.new()
	_speech_bubble.name = "SpeechBubble"
	_speech_bubble.position.y = BODY_HEIGHT * height_scale + SPEECH_HEIGHT_MARGIN
	add_child(_speech_bubble)


func _build_think_timer() -> void:
	_think_timer = Timer.new()
	_think_timer.name = "ThinkTimer"
	_think_timer.wait_time = randf_range(THINK_INTERVAL_MIN, THINK_INTERVAL_MAX)
	_think_timer.one_shot = false
	_think_timer.autostart = true
	add_child(_think_timer)
	_think_timer.timeout.connect(_on_think_timeout)


# --- Internals ---------------------------------------------------------------


func _on_think_timeout() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var elapsed: float = 0.0
	if _last_think_ms > 0:
		elapsed = float(now_ms - _last_think_ms) / 1000.0
	_last_think_ms = now_ms
	_think(elapsed)


func _on_avoidance_velocity(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity


func _finish_navigation() -> void:
	_has_navigation_target = false
	_safe_velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if _arrival_pending:
		_arrival_pending = false
		arrived.emit()
		_on_navigation_arrived()


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(
		rotation.y, target_yaw, 1.0 - exp(-TURN_DECAY * delta)
	)


func _pose_sitting(seated: bool) -> void:
	# Simple seated pose: sink the torso and head to stool height.
	var drop: float = Seat.SIT_HEIGHT * 0.55 if seated else 0.0
	var height_scale: float = race.height_scale if race != null else 1.0
	var body_height: float = BODY_HEIGHT * height_scale
	var torso: CapsuleMesh = _body_mesh.mesh as CapsuleMesh
	_body_mesh.position.y = torso.height * 0.5 - drop
	var head: SphereMesh = _head_mesh.mesh as SphereMesh
	_head_mesh.position.y = body_height - head.radius - drop
	_collision_shape.disabled = seated
