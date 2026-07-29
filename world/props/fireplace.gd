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

## 0 = resting fire, 1 = freshly stoked. Decays over time.
var stoke_level: float = 0.0

var _flicker_phase: float = 0.0

@onready var _fire_light: OmniLight3D = %FireLight
@onready var _flame_mesh: MeshInstance3D = %Flame


func _ready() -> void:
	super()
	# Each fireplace animates its own flame copy, not the shared material.
	var unique_material: ShaderMaterial = (
		_flame_mesh.get_active_material(0).duplicate() as ShaderMaterial
	)
	_flame_mesh.material_override = unique_material


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


func interact(_actor: Node3D) -> void:
	stoke_level = 1.0
	stoked.emit()
	EventBus.post_notification("The fire roars back to life.")
