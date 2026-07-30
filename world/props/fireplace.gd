class_name Fireplace
extends Interactable
## The tavern hearth: an interactable fire that can be stoked.
##
## Stoking briefly boosts flame intensity and light energy, then both decay
## back to their resting values. The flame material and light flicker are
## animated every frame for a lively hearth.

## Emitted whenever the player stokes the fire.
signal stoked

const REST_LIGHT_ENERGY: float = 2.4
const STOKED_LIGHT_ENERGY: float = 4.4
const REST_FLAME_INTENSITY: float = 1.0
const STOKED_FLAME_INTENSITY: float = 1.9
const STOKE_DECAY_PER_SECOND: float = 0.18
const FLICKER_SPEED: float = 11.0
const FLICKER_AMOUNT: float = 0.16

## Spark particle look.
const SPARK_COLOR: Color = Color(1.0, 0.55, 0.15)
const SPARK_AMOUNT_REST: int = 10
const SPARK_AMOUNT_STOKED: int = 26

## 0 = resting fire, 1 = freshly stoked. Decays over time.
var stoke_level: float = 0.0

var _flicker_phase: float = 0.0
var _sparks: GPUParticles3D = null

@onready var _fire_light: OmniLight3D = %FireLight
@onready var _flame_mesh: MeshInstance3D = %Flame


func _ready() -> void:
	super()
	# Each fireplace animates its own flame copy, not the shared material.
	var unique_material: ShaderMaterial = (
		_flame_mesh.get_active_material(0).duplicate() as ShaderMaterial
	)
	_flame_mesh.material_override = unique_material
	_build_sparks()


func _process(delta: float) -> void:
	stoke_level = maxf(0.0, stoke_level - STOKE_DECAY_PER_SECOND * delta)
	_flicker_phase += delta * FLICKER_SPEED
	var flicker: float = 1.0 + sin(_flicker_phase) * sin(_flicker_phase * 1.7) * FLICKER_AMOUNT
	_fire_light.light_energy = lerpf(
		REST_LIGHT_ENERGY, STOKED_LIGHT_ENERGY, stoke_level
	) * flicker
	var flame_material: ShaderMaterial = _flame_mesh.material_override as ShaderMaterial
	flame_material.set_shader_parameter(
		"intensity",
		lerpf(REST_FLAME_INTENSITY, STOKED_FLAME_INTENSITY, stoke_level)
	)
	_sparks.amount_ratio = lerpf(
		float(SPARK_AMOUNT_REST) / float(SPARK_AMOUNT_STOKED), 1.0, stoke_level
	)


func interact(_actor: Node3D) -> void:
	stoke_level = 1.0
	stoked.emit()
	EventBus.post_notification("The fire roars back to life.")


func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "Sparks"
	_sparks.amount = SPARK_AMOUNT_STOKED
	_sparks.lifetime = 1.4
	_sparks.position = Vector3(0.0, 0.35, 0.2)
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.15)
	process.spread = 16.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.3
	process.gravity = Vector3(0.0, 0.35, 0.0)
	process.damping_min = 0.4
	process.damping_max = 0.9
	process.scale_min = 0.35
	process.scale_max = 1.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.45, 0.06, 0.2)
	_sparks.process_material = process
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.02, 0.02)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = SPARK_COLOR
	material.emission_enabled = true
	material.emission = SPARK_COLOR
	material.emission_energy_multiplier = 2.4
	mesh.material = material
	_sparks.draw_pass_1 = mesh
	add_child(_sparks)
