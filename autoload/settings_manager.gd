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

const DEFAULT_MOUSE_SENSITIVITY: float = 0.09
const DEFAULT_INVERT_Y: bool = false
const DEFAULT_FIELD_OF_VIEW: float = 78.0
const DEFAULT_VIEW_BOB_ENABLED: bool = true

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
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("SettingsManager: failed to write %s (error %d)" % [SETTINGS_PATH, error])
