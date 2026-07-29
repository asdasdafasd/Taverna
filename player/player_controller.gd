class_name PlayerController
extends CharacterBody3D
## First/third-person tavern keeper controller.
##
## Grounded, deliberate PC movement: WASD, jump with coyote time and jump
## buffering, Shift or double-tap-forward sprint, smooth crouching, raw mouse
## look, camera mode toggle, and carry/drop of [CarryableProp] objects.

## Emitted whenever the crouch state flips.
signal crouch_changed(is_crouching: bool)

## Emitted when the player starts or stops sprinting.
signal sprint_changed(is_sprinting: bool)

# --- Movement tuning -------------------------------------------------------
const WALK_SPEED: float = 4.2
const SPRINT_SPEED: float = 6.0
const CROUCH_SPEED: float = 1.9
const GROUND_ACCEL_DECAY: float = 12.0
const AIR_ACCEL_DECAY: float = 3.5
const GRAVITY: float = 21.0
const JUMP_HEIGHT: float = 1.15
const COYOTE_TIME_SECONDS: float = 0.12
const JUMP_BUFFER_SECONDS: float = 0.14
const DOUBLE_TAP_SPRINT_WINDOW: float = 0.28

# --- Body dimensions -------------------------------------------------------
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.2
const CAPSULE_RADIUS: float = 0.32
const EYE_OFFSET_FROM_TOP: float = 0.16
const CROUCH_TRANSITION_DECAY: float = 14.0
const CEILING_CHECK_RADIUS: float = 0.28

# --- Camera tuning ---------------------------------------------------------
const PITCH_LIMIT_DEGREES: float = 89.0
const THIRD_PERSON_DISTANCE: float = 3.4
const CAMERA_MODE_DECAY: float = 10.0
const BODY_VISIBLE_ARM_LENGTH: float = 0.4
const SPRINT_FOV_BOOST: float = 8.0
const FOV_DECAY: float = 8.0
const VIEW_BOB_FREQUENCY: float = 9.0
const VIEW_BOB_AMPLITUDE: float = 0.035

var is_first_person: bool = true
var is_crouching: bool = false
var is_sprinting: bool = false
var carried_prop: CarryableProp = null

var _pitch_degrees: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _double_tap_timer: float = 0.0
var _double_tap_sprint_active: bool = false
var _current_height: float = STAND_HEIGHT
var _bob_phase: float = 0.0

@onready var _head: Node3D = %Head
@onready var _spring_arm: SpringArm3D = %SpringArm
@onready var _camera: Camera3D = %Camera
@onready var _interaction_ray: InteractionRay = %InteractionRay
@onready var _carry_anchor: Node3D = %CarryAnchor
@onready var _collision_shape: CollisionShape3D = %BodyShape
@onready var _capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
@onready var _body_mesh: MeshInstance3D = %BodyMesh
@onready var _body_capsule: CapsuleMesh = _body_mesh.mesh as CapsuleMesh
@onready var _ceiling_check: ShapeCast3D = %CeilingCheck


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	Input.use_accumulated_input = false
	_camera.fov = SettingsManager.field_of_view
	SettingsManager.settings_changed.connect(_on_settings_changed)
	_spring_arm.spring_length = 0.0
	_configure_ceiling_check()
	_apply_height(STAND_HEIGHT)


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(motion.relative)
		return
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera_mode()
	elif event.is_action_pressed("interact"):
		_handle_interact_pressed()
	elif event.is_action_pressed("drop"):
		drop_carried()
	elif event.is_action_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_SECONDS
	elif event.is_action_pressed("move_forward"):
		_register_forward_tap()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_crouch(delta)
	_update_sprint_state()
	_apply_gravity(delta)
	_try_consume_jump()
	_apply_horizontal_movement(delta)
	move_and_slide()
	_update_camera(delta)


## Carry hook used by [CarryableProp.interact]. Returns true on success.
func request_carry(prop: CarryableProp) -> bool:
	if carried_prop != null or prop == null:
		return false
	carried_prop = prop
	_interaction_ray.clear_focus()
	_interaction_ray.enabled = false
	prop.begin_carry(_carry_anchor)
	return true


## Releases the carried prop with a light toss along the view direction.
func drop_carried() -> void:
	if carried_prop == null:
		return
	var toss: Vector3 = -_head.global_basis.z + Vector3.UP * 0.25
	carried_prop.end_carry(toss)
	carried_prop = null
	_interaction_ray.enabled = true


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.player_position = global_position
	data.player_yaw = rotation.y


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	global_position = data.player_position
	rotation.y = data.player_yaw
	velocity = Vector3.ZERO


# --- Look and camera --------------------------------------------------------


func _apply_mouse_look(relative: Vector2) -> void:
	var sensitivity: float = SettingsManager.mouse_sensitivity
	var invert: float = -1.0 if SettingsManager.invert_y else 1.0
	rotate_y(deg_to_rad(-relative.x * sensitivity))
	_pitch_degrees = clampf(
		_pitch_degrees - relative.y * sensitivity * invert,
		-PITCH_LIMIT_DEGREES,
		PITCH_LIMIT_DEGREES
	)
	_head.rotation_degrees.x = _pitch_degrees


func _toggle_camera_mode() -> void:
	is_first_person = not is_first_person
	EventBus.camera_view_changed.emit(is_first_person)


func _update_camera(delta: float) -> void:
	var target_length: float = 0.0 if is_first_person else THIRD_PERSON_DISTANCE
	_spring_arm.spring_length = MathUtils.exp_decay(
		_spring_arm.spring_length, target_length, CAMERA_MODE_DECAY, delta
	)
	_interaction_ray.set_extra_reach(_spring_arm.spring_length)
	_body_mesh.visible = _spring_arm.spring_length > BODY_VISIBLE_ARM_LENGTH
	var target_fov: float = SettingsManager.field_of_view
	if is_sprinting and MathUtils.flat_speed(velocity) > WALK_SPEED:
		target_fov += SPRINT_FOV_BOOST
	_camera.fov = MathUtils.exp_decay(_camera.fov, target_fov, FOV_DECAY, delta)
	_update_view_bob(delta)


func _update_view_bob(delta: float) -> void:
	if not SettingsManager.view_bob_enabled or not is_first_person:
		_camera.position.y = MathUtils.exp_decay(_camera.position.y, 0.0, FOV_DECAY, delta)
		return
	var flat: float = MathUtils.flat_speed(velocity)
	if is_on_floor() and flat > 0.5:
		_bob_phase += delta * VIEW_BOB_FREQUENCY * (flat / WALK_SPEED)
		_camera.position.y = sin(_bob_phase) * VIEW_BOB_AMPLITUDE
	else:
		_camera.position.y = MathUtils.exp_decay(_camera.position.y, 0.0, FOV_DECAY, delta)


# --- Movement ---------------------------------------------------------------


func _update_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_double_tap_timer = maxf(0.0, _double_tap_timer - delta)
	if is_on_floor():
		_coyote_timer = COYOTE_TIME_SECONDS
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)


func _register_forward_tap() -> void:
	if _double_tap_timer > 0.0:
		_double_tap_sprint_active = true
	_double_tap_timer = DOUBLE_TAP_SPRINT_WINDOW


func _update_sprint_state() -> void:
	if not Input.is_action_pressed("move_forward"):
		_double_tap_sprint_active = false
	var wants_sprint: bool = (
		Input.is_action_pressed("sprint") or _double_tap_sprint_active
	)
	var moving_forward: bool = Input.get_axis("move_back", "move_forward") > 0.0
	var now_sprinting: bool = wants_sprint and moving_forward and not is_crouching
	if now_sprinting != is_sprinting:
		is_sprinting = now_sprinting
		sprint_changed.emit(is_sprinting)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _try_consume_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0 or is_crouching:
		return
	velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _apply_horizontal_movement(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction: Vector3 = (
		global_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	).normalized()
	var speed: float = _current_move_speed()
	var target: Vector3 = direction * speed
	var decay: float = GROUND_ACCEL_DECAY if is_on_floor() else AIR_ACCEL_DECAY
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = MathUtils.exp_decay_v3(horizontal, target, decay, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _current_move_speed() -> float:
	if is_crouching:
		return CROUCH_SPEED
	if is_sprinting:
		return SPRINT_SPEED
	return WALK_SPEED


# --- Crouch -----------------------------------------------------------------


func _update_crouch(delta: float) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	if wants_crouch != is_crouching:
		if wants_crouch or _can_stand_up():
			is_crouching = wants_crouch
			crouch_changed.emit(is_crouching)
	var target_height: float = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	if not is_equal_approx(_current_height, target_height):
		_apply_height(MathUtils.exp_decay(
			_current_height, target_height, CROUCH_TRANSITION_DECAY, delta
		))


func _can_stand_up() -> bool:
	_ceiling_check.force_shapecast_update()
	return not _ceiling_check.is_colliding()


func _apply_height(height: float) -> void:
	_current_height = height
	_capsule.height = height
	_collision_shape.position.y = height * 0.5
	_body_capsule.height = height
	_body_mesh.position.y = height * 0.5
	_head.position.y = height - EYE_OFFSET_FROM_TOP


func _configure_ceiling_check() -> void:
	# Cast a small sphere from the crouched torso up to standing head height
	# against the world layer only; a hit means the player cannot stand up.
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = CEILING_CHECK_RADIUS
	_ceiling_check.shape = sphere
	_ceiling_check.enabled = false
	_ceiling_check.collision_mask = 1
	_ceiling_check.position = Vector3(0.0, CROUCH_HEIGHT * 0.5, 0.0)
	_ceiling_check.target_position = Vector3(
		0.0, STAND_HEIGHT - CEILING_CHECK_RADIUS - CROUCH_HEIGHT * 0.5, 0.0
	)


# --- Interaction ------------------------------------------------------------


func _handle_interact_pressed() -> void:
	if carried_prop != null:
		drop_carried()
		return
	_interaction_ray.interact(self)


func _on_settings_changed() -> void:
	_camera.fov = SettingsManager.field_of_view
