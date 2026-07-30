class_name PauseMenu
extends CanvasLayer
## In-game pause menu: resume, save, load, settings, controls reference,
## and quit to the title screen.
##
## Shows whenever [code]GameManager[/code] enters PAUSED and hides on
## resume. Built in code to match the rest of the UI language.

const MENU_SCENE_PATH: String = "res://ui/menu/main_menu.tscn"
const TITLE_COLOR: Color = Color(0.96, 0.9, 0.78)
const HINT_COLOR: Color = Color(0.72, 0.66, 0.58)

const CONTROLS_TEXT: String = (
	"WASD move · Space jump · Shift sprint · Ctrl crouch\n"
	+ "V camera · E interact / talk · Q drop · Tab ledger\n"
	+ "F break up fight · G round on the house\n"
	+ "F5 quick save · F8 quick load"
)

var _root: Control = null
var _menu_box: VBoxContainer = null
var _settings_panel: SettingsPanel = null


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_root.visible = false
	GameManager.state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: int) -> void:
	var paused: bool = new_state == GameManager.State.PAUSED
	_root.visible = paused
	if paused:
		_settings_panel.visible = false
		_menu_box.visible = true


# --- Actions -----------------------------------------------------------------


func _on_resume_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	GameManager.resume_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_save_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	if SaveManager.save_game():
		EventBus.post_notification("Game saved.")


func _on_load_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	if not SaveManager.has_save():
		EventBus.post_notification("No save found yet.")
		return
	if SaveManager.load_game():
		GameManager.resume_game()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.post_notification("Game loaded.")
	else:
		EventBus.post_notification("Loading failed — see the log.")


func _on_settings_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	_menu_box.visible = false
	_settings_panel.visible = true


func _on_settings_closed() -> void:
	_settings_panel.visible = false
	_menu_box.visible = true


func _on_quit_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -8.0)
	# Unpause the tree before leaving, or the menu scene would start paused.
	GameManager.resume_game()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


# --- Construction ------------------------------------------------------------------


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.015, 0.01, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_menu_box = VBoxContainer.new()
	_menu_box.name = "Menu"
	_menu_box.add_theme_constant_override("separation", 8)
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.custom_minimum_size = Vector2(300, 0)
	_menu_box.position = Vector2(-150, -190)
	_root.add_child(_menu_box)

	var title: Label = Label.new()
	title.text = "Paused"
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(title)

	_add_button("Resume", _on_resume_pressed)
	_add_button("Save Game", _on_save_pressed)
	_add_button("Load Game", _on_load_pressed)
	_add_button("Settings", _on_settings_pressed)
	_add_button("Quit to Title", _on_quit_pressed)

	var hint: Label = Label.new()
	hint.text = CONTROLS_TEXT
	hint.add_theme_color_override("font_color", HINT_COLOR)
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(hint)

	_settings_panel = SettingsPanel.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-260, -260)
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	_root.add_child(_settings_panel)


func _add_button(text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(handler)
	_menu_box.add_child(button)
