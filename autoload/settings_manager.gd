extends Node
## Loads, stores, and persists user preferences.
##
## Settings are written to [code]user://settings.cfg[/code] whenever a value
## changes and reloaded on boot. Autoload name: [code]SettingsManager[/code].

## Emitted after any setting value changes.
signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION_INPUT: String = "input"
const SECTION_CAMERA: String = "camera"
const SECTION_AUDIO: String = "audio"

const DEFAULT_MOUSE_SENSITIVITY: float = 0.09
const DEFAULT_INVERT_Y: bool = false
const DEFAULT_FIELD_OF_VIEW: float = 78.0
const DEFAULT_VIEW_BOB_ENABLED: bool = true
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.7
const DEFAULT_AMBIENT_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 0.9

const MIN_MOUSE_SENSITIVITY: float = 0.01
const MAX_MOUSE_SENSITIVITY: float = 0.5
const MIN_FIELD_OF_VIEW: float = 60.0
const MAX_FIELD_OF_VIEW: float = 110.0

## Degrees of camera rotation per pixel of mouse travel.
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY:
	set(value):
		mouse_sensitivity = clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
		_persist()

var invert_y: bool = DEFAULT_INVERT_Y:
	set(value):
		invert_y = value
		_persist()

## Base camera field of view in degrees (sprint adds a temporary boost).
var field_of_view: float = DEFAULT_FIELD_OF_VIEW:
	set(value):
		field_of_view = clampf(value, MIN_FIELD_OF_VIEW, MAX_FIELD_OF_VIEW)
		_persist()

var view_bob_enabled: bool = DEFAULT_VIEW_BOB_ENABLED:
	set(value):
		view_bob_enabled = value
		_persist()

## Linear bus volumes in [0, 1].
var master_volume: float = DEFAULT_MASTER_VOLUME:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_persist()

var music_volume: float = DEFAULT_MUSIC_VOLUME:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_persist()

var ambient_volume: float = DEFAULT_AMBIENT_VOLUME:
	set(value):
		ambient_volume = clampf(value, 0.0, 1.0)
		_persist()

var sfx_volume: float = DEFAULT_SFX_VOLUME:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_persist()

var _loading: bool = false


func _ready() -> void:
	_load_from_disk()


func _load_from_disk() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error != OK:
		# First launch: keep defaults and write the initial file.
		_write_to_disk()
		return
	_loading = true
	mouse_sensitivity = float(
		config.get_value(SECTION_INPUT, "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)
	)
	invert_y = bool(config.get_value(SECTION_INPUT, "invert_y", DEFAULT_INVERT_Y))
	field_of_view = float(
		config.get_value(SECTION_CAMERA, "field_of_view", DEFAULT_FIELD_OF_VIEW)
	)
	view_bob_enabled = bool(
		config.get_value(SECTION_CAMERA, "view_bob_enabled", DEFAULT_VIEW_BOB_ENABLED)
	)
	master_volume = float(
		config.get_value(SECTION_AUDIO, "master_volume", DEFAULT_MASTER_VOLUME)
	)
	music_volume = float(
		config.get_value(SECTION_AUDIO, "music_volume", DEFAULT_MUSIC_VOLUME)
	)
	ambient_volume = float(
		config.get_value(SECTION_AUDIO, "ambient_volume", DEFAULT_AMBIENT_VOLUME)
	)
	sfx_volume = float(
		config.get_value(SECTION_AUDIO, "sfx_volume", DEFAULT_SFX_VOLUME)
	)
	_loading = false
	settings_changed.emit()


func _persist() -> void:
	if _loading:
		return
	_write_to_disk()
	settings_changed.emit()


func _write_to_disk() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_INPUT, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION_INPUT, "invert_y", invert_y)
	config.set_value(SECTION_CAMERA, "field_of_view", field_of_view)
	config.set_value(SECTION_CAMERA, "view_bob_enabled", view_bob_enabled)
	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "ambient_volume", ambient_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("SettingsManager: failed to write %s (error %d)" % [SETTINGS_PATH, error])
