class_name SpeechBubble
extends Label3D
## Overhead speech line for NPCs: fades in, holds, fades out.
##
## Lines are queued so rapid moments do not overwrite each other. The label
## billboards toward the camera and needs no textures.

const FADE_SECONDS: float = 0.18
const HOLD_SECONDS_BASE: float = 2.2
const HOLD_SECONDS_PER_CHAR: float = 0.035
const MAX_QUEUE: int = 3

var _queue: Array[String] = []
var _tween: Tween = null


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0008
	font_size = 30
	outline_size = 10
	modulate = Color(1.0, 0.96, 0.88, 0.0)
	outline_modulate = Color(0.08, 0.05, 0.03, 0.0)
	text = ""


## Queues [param line] for display. Empty lines are ignored.
func show_line(line: String) -> void:
	if line.is_empty():
		return
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append(line)
	if _tween == null or not _tween.is_running():
		_play_next()


func _play_next() -> void:
	if _queue.is_empty():
		return
	var line: String = _queue.pop_front()
	text = line
	var hold: float = HOLD_SECONDS_BASE + HOLD_SECONDS_PER_CHAR * float(line.length())
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(self, "outline_modulate:a", 0.9, FADE_SECONDS)
	_tween.set_parallel(false)
	_tween.tween_interval(hold)
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS * 2.0)
	_tween.tween_property(self, "outline_modulate:a", 0.0, FADE_SECONDS * 2.0)
	_tween.set_parallel(false)
	_tween.tween_callback(_play_next)
