class_name SettingsPanel
extends PanelContainer
## Reusable settings form (mouse, camera, audio) built in code.
##
## Binds directly to [code]SettingsManager[/code], which persists values on
## change, so the panel works identically from the main menu and the pause
## menu. Emits [signal closed] when the player is done.

## Emitted when the back button is pressed.
signal closed

const PANEL_COLOR: Color = Color(0.09, 0.065, 0.045, 0.97)
const HEADER_COLOR: Color = Color(0.96, 0.9, 0.78)
const ACCENT_COLOR: Color = Color(0.92, 0.78, 0.42)
const MUTED_COLOR: Color = Color(0.72, 0.66, 0.58)

var _column: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	add_theme_stylebox_override("panel", style)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", 8)
	add_child(_column)

	_add_title("Settings")
	_add_section("Mouse & Camera")
	_add_slider(
		"Mouse sensitivity",
		SettingsManager.MIN_MOUSE_SENSITIVITY, SettingsManager.MAX_MOUSE_SENSITIVITY,
		0.005, SettingsManager.mouse_sensitivity,
		func(value: float) -> void: SettingsManager.mouse_sensitivity = value
	)
	_add_slider(
		"Field of view",
		SettingsManager.MIN_FIELD_OF_VIEW, SettingsManager.MAX_FIELD_OF_VIEW,
		1.0, SettingsManager.field_of_view,
		func(value: float) -> void: SettingsManager.field_of_view = value
	)
	_add_toggle(
		"Invert Y axis", SettingsManager.invert_y,
		func(pressed: bool) -> void: SettingsManager.invert_y = pressed
	)
	_add_toggle(
		"View bob", SettingsManager.view_bob_enabled,
		func(pressed: bool) -> void: SettingsManager.view_bob_enabled = pressed
	)
	_add_section("Audio")
	_add_slider(
		"Master volume", 0.0, 1.0, 0.05, SettingsManager.master_volume,
		func(value: float) -> void: SettingsManager.master_volume = value
	)
	_add_slider(
		"Music", 0.0, 1.0, 0.05, SettingsManager.music_volume,
		func(value: float) -> void: SettingsManager.music_volume = value
	)
	_add_slider(
		"Ambience", 0.0, 1.0, 0.05, SettingsManager.ambient_volume,
		func(value: float) -> void: SettingsManager.ambient_volume = value
	)
	_add_slider(
		"Effects", 0.0, 1.0, 0.05, SettingsManager.sfx_volume,
		func(value: float) -> void: SettingsManager.sfx_volume = value
	)

	var back: Button = Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 38)
	back.pressed.connect(_on_back_pressed)
	_column.add_child(back)


func _on_back_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	closed.emit()


func _add_title(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOR)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(label)


func _add_section(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	label.add_theme_font_size_override("font_size", 16)
	_column.add_child(label)


func _add_slider(
	label_text: String, min_value: float, max_value: float,
	step: float, initial: float, on_change: Callable
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	label.add_theme_color_override("font_color", MUTED_COLOR)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	_column.add_child(row)


func _add_toggle(label_text: String, initial: bool, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	label.add_theme_color_override("font_color", MUTED_COLOR)
	row.add_child(label)
	var check: CheckButton = CheckButton.new()
	check.button_pressed = initial
	check.toggled.connect(on_change)
	row.add_child(check)
	_column.add_child(row)
