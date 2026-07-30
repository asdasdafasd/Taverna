class_name Hud
extends CanvasLayer
## In-game HUD: crosshair, interaction prompt, clock, funds, notifications,
## and pause overlay. All signal wiring happens in code.

const NOTIFICATION_SECONDS: float = 2.6
const CROSSHAIR_FOCUS_COLOR: Color = Color(1.0, 0.85, 0.5, 0.95)
const CROSSHAIR_IDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const TENSION_COLORS: Array[Color] = [
	Color(0.55, 0.8, 0.45), Color(0.95, 0.75, 0.3), Color(0.9, 0.35, 0.28),
]

var _notification_tween: Tween = null
var _focused_interactable: Interactable = null
## Cached per-level fill styles so tension ticks never allocate.
var _tension_styles: Array[StyleBoxFlat] = []
var _tension_level_shown: int = -1

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _funds_label: Label = %FundsLabel
@onready var _tension_bar: ProgressBar = %TensionBar
@onready var _notification_label: Label = %NotificationLabel


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prompt_label.text = ""
	_notification_label.modulate.a = 0.0
	_crosshair.modulate = CROSSHAIR_IDLE_COLOR
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.interaction_performed.connect(_on_interaction_performed)
	EventBus.carry_state_changed.connect(_on_carry_state_changed)
	EventBus.notification_posted.connect(_on_notification_posted)
	EventBus.patron_paid.connect(_on_patron_paid)
	TimeManager.minute_passed.connect(_on_minute_passed)
	GameManager.funds_changed.connect(_on_funds_changed)
	GameManager.state_changed.connect(_on_game_state_changed)
	TensionManager.tension_changed.connect(_on_tension_changed)
	TensionManager.warning_reached.connect(_on_tension_warning)
	TensionManager.critical_reached.connect(_on_tension_critical)
	_clock_label.text = TimeManager.clock_text()
	_funds_label.text = StringUtils.format_coins(GameManager.funds_copper)
	_on_tension_changed(TensionManager.tension)


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


func _on_patron_paid(patron: PatronNPC, copper_amount: int) -> void:
	_on_notification_posted(
		"%s paid %s." % [patron.npc_name, StringUtils.format_coins(copper_amount)]
	)


func _on_funds_changed(copper_total: int) -> void:
	_funds_label.text = StringUtils.format_coins(copper_total)


func _on_tension_changed(tension: float) -> void:
	_tension_bar.value = tension
	var level: int = TensionManager.level()
	if level == _tension_level_shown:
		return
	_tension_level_shown = level
	if _tension_styles.is_empty():
		for color: Color in TENSION_COLORS:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = color
			_tension_styles.append(style)
	_tension_bar.add_theme_stylebox_override("fill", _tension_styles[level])


func _on_tension_warning() -> void:
	_on_notification_posted("The room is getting uneasy...")


func _on_tension_critical() -> void:
	_on_notification_posted("The room is about to boil over!")


func _on_game_state_changed(new_state: int) -> void:
	_crosshair.visible = new_state == GameManager.State.PLAYING
