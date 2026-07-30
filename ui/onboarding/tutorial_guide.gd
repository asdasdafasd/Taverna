class_name TutorialGuide
extends CanvasLayer
## First-run onboarding: one short instruction card at a time, each
## advancing only when the player actually performs the action.
##
## Steps: move, look, interact, watch service happen, open the ledger.
## Completion (or skipping with H) is remembered both in the save file and
## in [code]user://profile.cfg[/code] so returning players never see it.

## Emitted when the tutorial finishes or is skipped.
signal tutorial_finished

enum Step {
	MOVE,
	LOOK,
	INTERACT,
	SERVICE,
	LEDGER,
	DONE,
}

const PROFILE_PATH: String = "user://profile.cfg"
const PROFILE_SECTION: String = "onboarding"

const PANEL_COLOR: Color = Color(0.09, 0.065, 0.045, 0.92)
const TITLE_COLOR: Color = Color(0.92, 0.78, 0.42)
const TEXT_COLOR: Color = Color(0.94, 0.9, 0.82)

## Seconds the final "done" card lingers before the panel hides itself.
const DONE_CARD_SECONDS: float = 3.0

## Mouse travel (pixels) that counts as "learned to look around".
const LOOK_TRAVEL_REQUIRED: float = 900.0

const STEP_TITLES: Dictionary[Step, String] = {
	Step.MOVE: "Find your feet",
	Step.LOOK: "Take in the room",
	Step.INTERACT: "Hands on the house",
	Step.SERVICE: "Let the house work",
	Step.LEDGER: "Mind the books",
	Step.DONE: "The Flagon is yours",
}

const STEP_TEXTS: Dictionary[Step, String] = {
	Step.MOVE: "Walk with WASD. Space jumps, Shift sprints, Ctrl crouches.",
	Step.LOOK: "Look around with the mouse. V switches to third person and back.",
	Step.INTERACT: "Aim the crosshair at a candle, door, or the hearth and press E.",
	Step.SERVICE:
		"Guests seat themselves and order; your staff pour and carry. "
		+ "Watch one order reach a table.",
	Step.LEDGER: "Press Tab to open the Keeper's Ledger — prices, stock, and coin.",
	Step.DONE: "That's the whole trade: keep them warm, fed, and peaceful.",
}

var completed: bool = false

var _step: Step = Step.MOVE
var _look_travel: float = 0.0
var _active: bool = false

var _root: Control = null
var _title_label: Label = null
var _text_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	layer = 15
	add_to_group(SaveManager.SAVE_GROUP)
	_build_interface()
	completed = _read_profile_flag("tutorial_done")
	if completed:
		_root.visible = false
		return
	_root.visible = false
	_wait_for_intro.call_deferred()


## Starts immediately, or after the intro's last beat when one is playing.
func _wait_for_intro() -> void:
	var intro: IntroSequence = null
	var intro_nodes: Array[Node] = get_tree().get_nodes_in_group(
		IntroSequence.INTRO_GROUP
	)
	if not intro_nodes.is_empty():
		intro = intro_nodes[0] as IntroSequence
	if intro != null and intro.is_playing:
		intro.intro_finished.connect(_activate, CONNECT_ONE_SHOT)
	else:
		_activate()


func _process(_delta: float) -> void:
	if not _active or _step != Step.MOVE:
		return
	var input_vector: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	if input_vector.length() > 0.5:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("tutorial_skip"):
		_finish(true)
		return
	if _step == Step.LOOK:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion != null:
			_look_travel += motion.relative.length()
			if _look_travel >= LOOK_TRAVEL_REQUIRED:
				_advance()


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.tutorial_done = completed


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	if data.tutorial_done and not completed:
		_finish(false)


func _activate() -> void:
	if completed:
		return
	_active = true
	_root.visible = true
	EventBus.interaction_performed.connect(_on_interaction_performed)
	EventBus.order_delivered.connect(_on_order_delivered)
	GameManager.state_changed.connect(_on_game_state_changed)
	_show_step()


func _advance() -> void:
	if _step >= Step.DONE:
		return
	_step = (_step + 1) as Step
	if _step == Step.DONE:
		_show_step()
		var timer: SceneTreeTimer = get_tree().create_timer(DONE_CARD_SECONDS)
		timer.timeout.connect(_finish.bind(true))
	else:
		_show_step()


func _show_step() -> void:
	_title_label.text = STEP_TITLES[_step]
	_text_label.text = STEP_TEXTS[_step]
	_hint_label.text = "" if _step == Step.DONE else "H — skip tutorial"


func _finish(mark: bool) -> void:
	if completed:
		return
	completed = true
	_active = false
	_root.visible = false
	if EventBus.interaction_performed.is_connected(_on_interaction_performed):
		EventBus.interaction_performed.disconnect(_on_interaction_performed)
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if GameManager.state_changed.is_connected(_on_game_state_changed):
		GameManager.state_changed.disconnect(_on_game_state_changed)
	if mark:
		_write_profile_flag("tutorial_done")
	tutorial_finished.emit()


func _on_interaction_performed(_interactable: Interactable, _actor: Node3D) -> void:
	if _step == Step.INTERACT:
		_advance()


func _on_order_delivered(_order: PatronOrder) -> void:
	if _step == Step.SERVICE:
		_advance()


func _on_game_state_changed(new_state: int) -> void:
	if _step == Step.LEDGER and new_state == GameManager.State.MANAGEMENT:
		_advance()


# --- Profile persistence ---------------------------------------------------------


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


# --- Construction ------------------------------------------------------------------


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.position = Vector2(-260, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_title_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	_text_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48))
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint_label)
