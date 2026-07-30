class_name DialoguePanel
extends CanvasLayer
## Paged conversation panel for story characters.
##
## Shows one page at a time with click/E to advance; supports a two-way
## choice page (the Accord decision). Pauses the world while open and
## reports the finished conversation to the EventBus so quests advance.
## A single instance lives in the main scene and is reached through
## [member _instance].

const PANEL_COLOR: Color = Color(0.09, 0.065, 0.045, 0.97)
const NAME_COLOR: Color = Color(0.92, 0.78, 0.42)
const TEXT_COLOR: Color = Color(0.94, 0.9, 0.82)
const HINT_COLOR: Color = Color(0.62, 0.56, 0.48)

static var _instance: DialoguePanel = null

var is_open: bool = false

var _character: StoryCharacterNPC = null
var _pages: Array[String] = []
var _page_index: int = 0
var _choice: Dictionary = {}
var _in_choice: bool = false

var _root: Control = null
var _name_label: Label = null
var _text_label: Label = null
var _hint_label: Label = null
var _choice_row: HBoxContainer = null
var _renew_button: Button = null
var _fade_button: Button = null


## Opens the panel for [param character] (called from the character).
static func instance_open(character: StoryCharacterNPC) -> void:
	if _instance != null:
		_instance.open_for(character)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instance = self
	_build_interface()
	_root.visible = false


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or _in_choice:
		return
	var advance: bool = event.is_action_pressed("interact")
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		_advance_page()
		get_viewport().set_input_as_handled()


## Builds the page list from the character's current stage and shows it.
func open_for(character: StoryCharacterNPC) -> void:
	if is_open or GameManager.state != GameManager.State.PLAYING:
		return
	if get_tree().paused:
		return
	var stage: Dictionary = StoryDialogue.stage_for(character.character_id)
	if stage.is_empty():
		return
	_character = character
	_pages.clear()
	_choice = stage.get("choice", {})
	for page_source: Variant in stage.get("pages", []):
		_pages.append(str(page_source))
	if _pages.is_empty() and _choice.is_empty():
		return
	is_open = true
	get_tree().paused = true
	TimeManager.clock_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_name_label.text = character.npc_name
	_page_index = -1
	if _pages.is_empty():
		_show_choice()
	else:
		_advance_page()


func _advance_page() -> void:
	_page_index += 1
	if _page_index < _pages.size():
		_text_label.text = _pages[_page_index]
		var last_page: bool = _page_index == _pages.size() - 1
		if last_page and not _choice.is_empty():
			_hint_label.text = "E / click — continue"
		elif last_page:
			_hint_label.text = "E / click — end conversation"
		else:
			_hint_label.text = "E / click — continue"
		return
	if not _choice.is_empty():
		_show_choice()
	else:
		_close()


func _show_choice() -> void:
	_in_choice = true
	_text_label.text = str(_choice.get("prompt", ""))
	_hint_label.text = "Choose."
	_choice_row.visible = true
	_renew_button.text = str(_choice.get("renew_label", "Agree"))
	_fade_button.text = str(_choice.get("fade_label", "Refuse"))
	_renew_button.grab_focus()


func _on_choice(renewed: bool) -> void:
	_in_choice = false
	_choice_row.visible = false
	StoryManager.make_accord_choice(renewed)
	var pages_key: String = "renew_pages" if renewed else "fade_pages"
	_pages.clear()
	for page_source: Variant in _choice.get(pages_key, []):
		_pages.append(str(page_source))
	_choice = {}
	_page_index = -1
	if _pages.is_empty():
		_close()
	else:
		_advance_page()


func _close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false
	TimeManager.clock_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var talked_to: StringName = _character.character_id
	_character = null
	EventBus.story_character_talked.emit(talked_to)


# --- Construction -------------------------------------------------------------


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(760, 220)
	panel.position = Vector2(-380, -270)
	_root.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	_name_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	_text_label.add_theme_font_size_override("font_size", 17)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0, 100)
	column.add_child(_text_label)

	_choice_row = HBoxContainer.new()
	_choice_row.name = "ChoiceRow"
	_choice_row.add_theme_constant_override("separation", 16)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.visible = false
	_renew_button = Button.new()
	_renew_button.name = "RenewButton"
	_renew_button.custom_minimum_size = Vector2(220, 40)
	_renew_button.pressed.connect(_on_choice.bind(true))
	_choice_row.add_child(_renew_button)
	_fade_button = Button.new()
	_fade_button.name = "FadeButton"
	_fade_button.custom_minimum_size = Vector2(220, 40)
	_fade_button.pressed.connect(_on_choice.bind(false))
	_choice_row.add_child(_fade_button)
	column.add_child(_choice_row)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint_label)
