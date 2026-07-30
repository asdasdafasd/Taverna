class_name QuestTracker
extends PanelContainer
## Compact on-screen quest tracker (top-right of the HUD).
##
## Shows the most recently progressed active quest with live objective
## lines, updating from [code]QuestManager[/code] signals. Hides itself
## when no quest is active so the HUD stays clean.

const TITLE_COLOR: Color = Color(0.92, 0.78, 0.42)
const OBJECTIVE_COLOR: Color = Color(0.94, 0.9, 0.82)
const DONE_COLOR: Color = Color(0.55, 0.8, 0.45)
const PANEL_COLOR: Color = Color(0.06, 0.045, 0.03, 0.72)

## Objective lines shown at most (keeps the tracker compact).
const MAX_OBJECTIVE_LINES: int = 4

var _tracked: QuestDefinition = null
var _title_label: Label = null
var _objectives_box: VBoxContainer = null


func _ready() -> void:
	_build_interface()
	QuestManager.quest_started.connect(_on_quest_started)
	QuestManager.quest_progressed.connect(_on_quest_progressed)
	QuestManager.quest_completed.connect(_on_quest_state_ended)
	QuestManager.quest_failed.connect(_on_quest_state_ended)
	EventBus.game_loaded.connect(_on_game_loaded)
	_track(_pick_default_quest())


func _on_quest_started(quest: QuestDefinition) -> void:
	# Newly unlocked quests take the tracker only when nothing is tracked.
	if _tracked == null:
		_track(quest)


func _on_quest_progressed(quest: QuestDefinition) -> void:
	# The quest the player is actually advancing wins the tracker slot.
	_track(quest)


func _on_quest_state_ended(quest: QuestDefinition) -> void:
	if quest == _tracked:
		_track(_pick_default_quest())


## Quest states may change wholesale on load; re-pick from scratch.
func _on_game_loaded(_path: String) -> void:
	_track(_pick_default_quest())


func _track(quest: QuestDefinition) -> void:
	_tracked = quest
	_refresh()


func _pick_default_quest() -> QuestDefinition:
	var active: Array[QuestDefinition] = QuestManager.active_quests()
	return active[0] if not active.is_empty() else null


func _refresh() -> void:
	if _tracked == null or not _tracked.is_active():
		visible = false
		return
	visible = true
	_title_label.text = _tracked.title
	for child: Node in _objectives_box.get_children():
		child.queue_free()
	var shown: int = 0
	for objective: QuestObjective in _tracked.objectives:
		if shown >= MAX_OBJECTIVE_LINES:
			break
		shown += 1
		var line: Label = Label.new()
		var mark: String = "[x]" if objective.is_done() else "[ ]"
		line.text = "%s %s" % [mark, objective.progress_text()]
		line.add_theme_font_size_override("font_size", 13)
		line.add_theme_color_override(
			"font_color", DONE_COLOR if objective.is_done() else OBJECTIVE_COLOR
		)
		_objectives_box.add_child(line)


func _build_interface() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_title_label)

	_objectives_box = VBoxContainer.new()
	_objectives_box.name = "Objectives"
	_objectives_box.add_theme_constant_override("separation", 1)
	column.add_child(_objectives_box)
