class_name IntroSequence
extends CanvasLayer
## Short skippable opening: Aldous's bequest letter fading in over black,
## three beats, then the tavern. Never blocks input handling — any key,
## click, or Esc skips straight to play. Shown once per profile.

## Emitted when the intro ends (played out or skipped).
signal intro_finished

## Group other systems (the tutorial) use to find the running intro.
const INTRO_GROUP: StringName = &"intro_sequence"

const PROFILE_PATH: String = "user://profile.cfg"
const PROFILE_SECTION: String = "onboarding"

const BEAT_SECONDS: float = 4.2
const FADE_SECONDS: float = 0.8
const TEXT_COLOR: Color = Color(0.9, 0.84, 0.72)

const BEATS: Array[String] = [
	"\"To my grandchild —\n\nThe lawyers will call it a tavern. Sign anyway.\"",
	"\"The Wandering Flagon is older than our name, and it has kept more"
	+ " than travelers warm. Keep it fed. Keep it kind. Keep it standing.\"",
	"\"The rest you will find under the floor, in the ledger, and in the"
	+ " regulars — in that order.\n\n— Aldous, keeper before you\"",
]

var is_playing: bool = false

var _root: Control = null
var _black: ColorRect = null
var _letter_label: Label = null
var _skip_label: Label = null
var _beat_index: int = 0
var _tween: Tween = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(SaveManager.SAVE_GROUP)
	add_to_group(INTRO_GROUP)
	_build_interface()
	if _read_profile_flag("intro_seen"):
		_root.visible = false
		intro_finished.emit.call_deferred()
		return
	_play()


func _input(event: InputEvent) -> void:
	if not is_playing:
		return
	var key: InputEventKey = event as InputEventKey
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (key != null and key.pressed) or (click != null and click.pressed):
		_finish()
		get_viewport().set_input_as_handled()


func _play() -> void:
	is_playing = true
	_root.visible = true
	_beat_index = -1
	_next_beat()


func _next_beat() -> void:
	_beat_index += 1
	if _beat_index >= BEATS.size():
		_finish()
		return
	_letter_label.text = BEATS[_beat_index]
	_letter_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_letter_label, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_interval(BEAT_SECONDS - FADE_SECONDS * 2.0)
	_tween.tween_property(_letter_label, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(_next_beat)


func _finish() -> void:
	if not is_playing:
		return
	is_playing = false
	if _tween != null:
		_tween.kill()
	var fade_out: Tween = create_tween()
	fade_out.tween_property(_root, "modulate:a", 0.0, 0.5)
	fade_out.tween_callback(_hide_and_report)
	_write_profile_flag("intro_seen")


func _hide_and_report() -> void:
	_root.visible = false
	intro_finished.emit()


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.intro_seen = not is_playing


## SaveManager participant hook: loading a running game always skips.
func read_save_data(data: SaveData) -> void:
	if data.intro_seen and is_playing:
		_finish()


func _read_profile_flag(key: String) -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
	return bool(config.get_value(PROFILE_SECTION, key, false))


func _write_profile_flag(key: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value(PROFILE_SECTION, key, true)
	config.save(PROFILE_PATH)


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0.01, 0.008, 0.012, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)

	_letter_label = Label.new()
	_letter_label.name = "LetterLabel"
	_letter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter_label.add_theme_color_override("font_color", TEXT_COLOR)
	_letter_label.add_theme_font_size_override("font_size", 24)
	_letter_label.set_anchors_preset(Control.PRESET_CENTER)
	_letter_label.custom_minimum_size = Vector2(720, 260)
	_letter_label.position = Vector2(-360, -130)
	_letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_letter_label)

	_skip_label = Label.new()
	_skip_label.name = "SkipLabel"
	_skip_label.text = "any key — skip"
	_skip_label.add_theme_color_override("font_color", Color(0.5, 0.46, 0.4))
	_skip_label.add_theme_font_size_override("font_size", 13)
	_skip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_label.position = Vector2(-140, -40)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_skip_label)
