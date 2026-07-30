class_name MainMenu
extends Control
## Title screen: continue, new game, settings, and quit over a warm
## animated backdrop. This is the project's boot scene; starting play
## loads [code]res://game/main/main.tscn[/code].

const GAME_SCENE_PATH: String = "res://game/main/main.tscn"
const BACKDROP_TOP: Color = Color(0.16, 0.1, 0.06)
const BACKDROP_BOTTOM: Color = Color(0.03, 0.02, 0.015)
const TITLE_COLOR: Color = Color(0.96, 0.88, 0.7)
const SUBTITLE_COLOR: Color = Color(0.72, 0.62, 0.48)
const EMBER_COLOR: Color = Color(1.0, 0.62, 0.25)
const EMBER_COUNT: int = 26

var _buttons_box: VBoxContainer = null
var _settings_panel: SettingsPanel = null
var _menu_root: VBoxContainer = null
var _embers: Array[Dictionary] = []
var _backdrop: Control = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The world clock must not advance (and fire events) on the title.
	TimeManager.clock_paused = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_menu()
	_build_settings()
	_seed_embers()


func _process(delta: float) -> void:
	for ember: Dictionary in _embers:
		ember["y"] = float(ember["y"]) - float(ember["speed"]) * delta
		ember["x"] = float(ember["x"]) + sin(
			Time.get_ticks_msec() / 1000.0 * float(ember["sway"]) + float(ember["phase"])
		) * 12.0 * delta
		if float(ember["y"]) < -0.05:
			ember["y"] = 1.05
			ember["x"] = randf()
	_backdrop.queue_redraw()


func _on_backdrop_draw() -> void:
	var size_now: Vector2 = _backdrop.size
	_backdrop.draw_rect(Rect2(Vector2.ZERO, size_now), BACKDROP_BOTTOM)
	# Vertical gradient bands (cheap, resolution independent).
	var bands: int = 24
	for band: int in bands:
		var t: float = float(band) / float(bands)
		var color: Color = BACKDROP_TOP.lerp(BACKDROP_BOTTOM, t)
		_backdrop.draw_rect(
			Rect2(0.0, size_now.y * t, size_now.x, size_now.y / bands + 1.0), color
		)
	for ember: Dictionary in _embers:
		var position: Vector2 = Vector2(
			float(ember["x"]) * size_now.x, float(ember["y"]) * size_now.y
		)
		var alpha: float = 0.25 + 0.5 * float(ember["glow"])
		_backdrop.draw_circle(
			position, float(ember["radius"]), Color(EMBER_COLOR, alpha)
		)


func _seed_embers() -> void:
	for _index: int in EMBER_COUNT:
		_embers.append({
			"x": randf(),
			"y": randf(),
			"speed": randf_range(0.015, 0.05),
			"radius": randf_range(1.2, 3.2),
			"glow": randf(),
			"sway": randf_range(0.4, 1.2),
			"phase": randf() * TAU,
		})


# --- Actions --------------------------------------------------------------------


func _on_continue_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -6.0)
	StartupOptions.load_save_on_start = true
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_new_game_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -6.0)
	StartupOptions.load_save_on_start = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_settings_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -6.0)
	_menu_root.visible = false
	_settings_panel.visible = true


func _on_settings_closed() -> void:
	_settings_panel.visible = false
	_menu_root.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Construction ------------------------------------------------------------------


func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_on_backdrop_draw)
	add_child(_backdrop)


func _build_menu() -> void:
	_menu_root = VBoxContainer.new()
	_menu_root.name = "Menu"
	_menu_root.add_theme_constant_override("separation", 10)
	_menu_root.set_anchors_preset(Control.PRESET_CENTER)
	_menu_root.custom_minimum_size = Vector2(340, 0)
	_menu_root.position = Vector2(-170, -190)
	add_child(_menu_root)

	var title: Label = Label.new()
	title.text = "The Wandering Flagon"
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_root.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "a tavern with a long memory"
	subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_root.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	_menu_root.add_child(spacer)

	_buttons_box = VBoxContainer.new()
	_buttons_box.name = "Buttons"
	_buttons_box.add_theme_constant_override("separation", 8)
	_menu_root.add_child(_buttons_box)

	if SaveManager.has_save():
		_add_button("Continue", _on_continue_pressed)
	_add_button("New Game", _on_new_game_pressed)
	_add_button("Settings", _on_settings_pressed)
	_add_button("Quit", _on_quit_pressed)

	var version: Label = Label.new()
	version.text = "v%s" % str(
		ProjectSettings.get_setting("application/config/version", "1.0")
	)
	version.add_theme_color_override("font_color", SUBTITLE_COLOR)
	version.add_theme_font_size_override("font_size", 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_root.add_child(version)


func _add_button(text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(handler)
	_buttons_box.add_child(button)


func _build_settings() -> void:
	_settings_panel = SettingsPanel.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-260, -260)
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	add_child(_settings_panel)
