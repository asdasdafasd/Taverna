class_name Hud
extends CanvasLayer
## In-game HUD: crosshair, interaction prompt, clock, funds, notifications,
## and pause overlay. All signal wiring happens in code.

const NOTIFICATION_SECONDS: float = 2.6
const CROSSHAIR_FOCUS_COLOR: Color = Color(1.0, 0.85, 0.5, 0.95)
const CROSSHAIR_IDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)

var _notification_tween: Tween = null
var _focused_interactable: Interactable = null

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _funds_label: Label = %FundsLabel
@onready var _notification_label: Label = %NotificationLabel
@onready var _pause_overlay: Control = %PauseOverlay


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prompt_label.text = ""
	_notification_label.modulate.a = 0.0
	_pause_overlay.visible = false
	_crosshair.modulate = CROSSHAIR_IDLE_COLOR
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.interaction_performed.connect(_on_interaction_performed)
	EventBus.carry_state_changed.connect(_on_carry_state_changed)
	EventBus.notification_posted.connect(_on_notification_posted)
	TimeManager.minute_passed.connect(_on_minute_passed)
	GameManager.funds_changed.connect(_on_funds_changed)
	GameManager.state_changed.connect(_on_game_state_changed)
	_clock_label.text = TimeManager.clock_text()
	_funds_label.text = StringUtils.format_coins(GameManager.funds_copper)


func _on_focus_changed(interactable: Interactable) -> void:
	_focused_interactable = interactable
	if interactable == null:
		_prompt_label.text = ""
		_crosshair.modulate = CROSSHAIR_IDLE_COLOR
	else:
		_prompt_label.text = "[E] %s" % interactable.get_prompt_text()
		_crosshair.modulate = CROSSHAIR_FOCUS_COLOR


## Refreshes the prompt after an interaction changes an object's state
## (e.g. a door's verb flips from Open to Close without refocusing).
func _on_interaction_performed(interactable: Interactable, _actor: Node3D) -> void:
	if interactable == _focused_interactable and interactable != null:
		_prompt_label.text = "[E] %s" % interactable.get_prompt_text()


func _on_carry_state_changed(prop: CarryableProp, is_carried: bool) -> void:
	if is_carried:
		_prompt_label.text = "[Q] Drop — %s" % prop.display_name
	else:
		_prompt_label.text = ""


func _on_notification_posted(text: String) -> void:
	_notification_label.text = text
	if _notification_tween != null:
		_notification_tween.kill()
	_notification_label.modulate.a = 1.0
	_notification_tween = create_tween()
	_notification_tween.tween_interval(NOTIFICATION_SECONDS)
	_notification_tween.tween_property(_notification_label, "modulate:a", 0.0, 0.6)


func _on_minute_passed(_day: int, _hour: int, _minute: int) -> void:
	_clock_label.text = TimeManager.clock_text()


func _on_funds_changed(copper_total: int) -> void:
	_funds_label.text = StringUtils.format_coins(copper_total)


func _on_game_state_changed(new_state: int) -> void:
	_pause_overlay.visible = new_state == GameManager.State.PAUSED
	_crosshair.visible = new_state != GameManager.State.PAUSED
