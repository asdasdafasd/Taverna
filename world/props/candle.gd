class_name Candle
extends Interactable
## A table candle the player can light or snuff.
##
## The flame quad and its omni light flicker gently while lit. Interacting
## toggles the lit state.

## Emitted when the candle is lit or snuffed.
signal lit_changed(is_lit: bool)

const LIT_LIGHT_ENERGY: float = 0.55
const FLICKER_SPEED: float = 9.0
const FLICKER_AMOUNT: float = 0.22

@export var starts_lit: bool = true

var is_lit: bool = true

var _flicker_phase: float = 0.0

@onready var _candle_light: OmniLight3D = %CandleLight
@onready var _flame_mesh: MeshInstance3D = %Flame


func _ready() -> void:
	super()
	# Random phase so a room full of candles never flickers in sync.
	_flicker_phase = randf() * TAU
	_set_lit(starts_lit)


func _process(delta: float) -> void:
	if not is_lit:
		return
	_flicker_phase += delta * FLICKER_SPEED
	var flicker: float = 1.0 + sin(_flicker_phase) * sin(_flicker_phase * 2.3) * FLICKER_AMOUNT
	_candle_light.light_energy = LIT_LIGHT_ENERGY * flicker


func get_prompt_text() -> String:
	var verb: String = "Snuff" if is_lit else "Light"
	return "%s — %s" % [verb, display_name]


func interact(_actor: Node3D) -> void:
	_set_lit(not is_lit)
	lit_changed.emit(is_lit)


func _set_lit(lit: bool) -> void:
	is_lit = lit
	_candle_light.visible = lit
	_flame_mesh.visible = lit
