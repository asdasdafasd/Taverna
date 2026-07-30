class_name FootstepPlayer
extends Node
## Plays wood footstep sounds timed to the player's actual gait.
##
## Child of [PlayerController]; distance-based stepping so cadence tracks
## walk, sprint, and crouch speeds naturally. Randomizes between three
## step samples with slight pitch drift.

const STEP_DISTANCE_WALK: float = 1.9
const STEP_DISTANCE_CROUCH: float = 1.3
const PITCH_JITTER: float = 0.12
const STEP_PATHS: Array[String] = [
	"res://assets/audio/footstep_wood_1.wav",
	"res://assets/audio/footstep_wood_2.wav",
	"res://assets/audio/footstep_wood_3.wav",
]

var _player: PlayerController = null
var _stream_player: AudioStreamPlayer = null
var _streams: Array[AudioStream] = []
var _distance_accumulator: float = 0.0
var _last_index: int = -1


func _ready() -> void:
	_player = get_parent() as PlayerController
	assert(_player != null, "FootstepPlayer must be a child of PlayerController")
	_stream_player = AudioStreamPlayer.new()
	_stream_player.name = "StepVoice"
	_stream_player.bus = AudioManager.BUS_SFX
	_stream_player.volume_db = -12.0
	add_child(_stream_player)
	for path: String in STEP_PATHS:
		var stream: AudioStream = load(path)
		if stream != null:
			_streams.append(stream)


func _physics_process(delta: float) -> void:
	if _streams.is_empty() or not _player.is_on_floor():
		return
	var speed: float = MathUtils.flat_speed(_player.velocity)
	if speed < 0.4:
		_distance_accumulator = 0.0
		return
	_distance_accumulator += speed * delta
	var stride: float = (
		STEP_DISTANCE_CROUCH if _player.is_crouching else STEP_DISTANCE_WALK
	)
	if _distance_accumulator >= stride:
		_distance_accumulator = 0.0
		_play_step()


func _play_step() -> void:
	var index: int = randi() % _streams.size()
	if index == _last_index:
		index = (index + 1) % _streams.size()
	_last_index = index
	_stream_player.stream = _streams[index]
	_stream_player.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	_stream_player.play()
