extends Node
## Loads quest definitions, routes gameplay events into objectives, applies
## rewards, and persists progress.
##
## Quests are defined in [code]res://data/quests/quests.json[/code] and
## unlock automatically when their prerequisite quests and story flags are
## met. All progress flows through [method _dispatch]: gameplay signals are
## translated into (type, target, amount) events matched against active
## quests' objectives and failure triggers.
## Autoload name: [code]QuestManager[/code].

## Emitted when a quest becomes ACTIVE.
signal quest_started(quest: QuestDefinition)

## Emitted whenever an active quest's objective progress changes.
signal quest_progressed(quest: QuestDefinition)

## Emitted when a quest completes (after rewards are applied).
signal quest_completed(quest: QuestDefinition)

## Emitted when a quest fails.
signal quest_failed(quest: QuestDefinition)

const QUESTS_PATH: String = "res://data/quests/quests.json"

## Threshold-style objective types (progress mirrors a value, not a count).
const THRESHOLD_TYPES: Array[String] = [
	"funds_reach", "reputation_reach", "gathering",
]

var _quests: Dictionary[StringName, QuestDefinition] = {}
var _quest_order: Array[StringName] = []
var _brawl_free_day: bool = true
var _was_critical: bool = false


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_load_quests()
	_connect_gameplay_signals()
	_refresh_unlocks.call_deferred()


## All quests in definition order (for the journal UI).
func all_quests() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for quest_id: StringName in _quest_order:
		result.append(_quests[quest_id])
	return result


func get_quest(quest_id: StringName) -> QuestDefinition:
	return _quests.get(quest_id)


## True when [param quest_id] is currently ACTIVE.
func is_quest_active(quest_id: StringName) -> bool:
	var quest: QuestDefinition = get_quest(quest_id)
	return quest != null and quest.is_active()


func active_quests() -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	for quest: QuestDefinition in all_quests():
		if quest.is_active():
			result.append(quest)
	return result


func completed_count() -> int:
	var count: int = 0
	for quest: QuestDefinition in all_quests():
		if quest.status == QuestDefinition.Status.COMPLETED:
			count += 1
	return count


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.quest_states.clear()
	for quest_id: StringName in _quest_order:
		var quest: QuestDefinition = _quests[quest_id]
		var progress: Array = []
		for objective: QuestObjective in quest.objectives:
			progress.append(objective.progress)
		data.quest_states[String(quest_id)] = {
			"status": quest.status,
			"progress": progress,
		}


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	for quest_key: String in data.quest_states:
		var quest: QuestDefinition = _quests.get(StringName(quest_key))
		if quest == null:
			continue
		var state: Dictionary = data.quest_states[quest_key]
		quest.status = clampi(
			int(state.get("status", QuestDefinition.Status.LOCKED)),
			QuestDefinition.Status.LOCKED,
			QuestDefinition.Status.FAILED
		) as QuestDefinition.Status
		var progress: Array = state.get("progress", [])
		for index: int in quest.objectives.size():
			if index < progress.size():
				quest.objectives[index].progress = int(progress[index])
	_refresh_unlocks()


# --- Event routing --------------------------------------------------------------


func _connect_gameplay_signals() -> void:
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.patron_paid.connect(_on_patron_paid)
	EventBus.patron_entered.connect(_on_patron_entered)
	EventBus.patron_seated.connect(_on_patron_seated)
	EventBus.patron_left.connect(_on_patron_left)
	EventBus.brawl_started.connect(_on_brawl_started)
	EventBus.brawl_ended.connect(_on_brawl_ended)
	EventBus.brawl_calmed.connect(_on_brawl_calmed)
	EventBus.furniture_repaired.connect(_on_furniture_repaired)
	EventBus.item_restocked.connect(_on_item_restocked)
	EventBus.story_character_talked.connect(_on_story_character_talked)
	EventBus.story_marker_activated.connect(_on_story_marker_activated)
	EventBus.story_flag_set.connect(_on_story_flag_set)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	GameManager.state_changed.connect(_on_game_state_changed)
	GameManager.funds_changed.connect(_on_funds_changed)
	ReputationManager.reputation_changed.connect(_on_reputation_changed)
	TensionManager.level_changed.connect(_on_tension_level_changed)
	TimeManager.day_passed.connect(_on_day_passed)


func _on_order_delivered(_order: PatronOrder) -> void:
	_dispatch("serve_orders", "", 1)


func _on_patron_paid(_patron: PatronNPC, _copper_amount: int) -> void:
	_dispatch("paid_patrons", "", 1)


func _on_patron_entered(patron: PatronNPC) -> void:
	_dispatch("race_visit", String(patron.race.id), 1)


func _on_patron_seated(_patron: PatronNPC, _seat: Seat) -> void:
	if TensionManager.level() == TensionManager.Level.CALM:
		_dispatch_threshold("gathering", "", _occupied_seat_count())


func _on_patron_left(_patron: PatronNPC) -> void:
	pass


func _on_brawl_started(_initiator: PatronNPC, _target: PatronNPC) -> void:
	_brawl_free_day = false
	_dispatch_failure("brawl_started", "")


func _on_brawl_ended(_initiator: PatronNPC, _target: PatronNPC) -> void:
	_dispatch("end_brawls", "", 1)


func _on_brawl_calmed(_fighter: PatronNPC) -> void:
	_dispatch("calm_brawl", "", 1)


func _on_furniture_repaired() -> void:
	_dispatch("repair_furniture", "", 1)


func _on_item_restocked(_item_id: StringName) -> void:
	_dispatch("restock_any", "", 1)


func _on_story_character_talked(character_id: StringName) -> void:
	_dispatch("talk_to", String(character_id), 1)


func _on_story_marker_activated(marker_id: StringName) -> void:
	_dispatch("examine_marker", String(marker_id), 1)


func _on_story_flag_set(flag: StringName) -> void:
	_dispatch("flag_set", String(flag), 1)
	_refresh_unlocks()


func _on_upgrade_purchased(_upgrade: UpgradeData) -> void:
	_dispatch("buy_upgrade", "", 1)


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.State.MANAGEMENT:
		_dispatch("open_ledger", "", 1)


func _on_funds_changed(copper_total: int) -> void:
	_dispatch_threshold("funds_reach", "", copper_total)


func _on_reputation_changed(race_id: StringName, value: float) -> void:
	_dispatch_threshold("reputation_reach", String(race_id), int(value))


func _on_tension_level_changed(new_level: int) -> void:
	if new_level == TensionManager.Level.CRITICAL:
		_was_critical = true
	elif new_level == TensionManager.Level.CALM and _was_critical:
		_was_critical = false
		_dispatch("tension_recover", "", 1)


func _on_day_passed(_day: int) -> void:
	if _brawl_free_day:
		_dispatch("day_survived", "", 1)
	_brawl_free_day = true


# --- Core dispatch ----------------------------------------------------------------


func _dispatch(event_type: String, event_target: String, amount: int) -> void:
	for quest: QuestDefinition in all_quests():
		if not quest.is_active():
			continue
		var changed: bool = false
		for objective: QuestObjective in quest.objectives:
			if not _matches(objective.type, objective.target, event_type, event_target):
				continue
			if objective.advance(amount):
				changed = true
		if changed:
			_after_progress(quest)


func _dispatch_threshold(event_type: String, event_target: String, value: int) -> void:
	for quest: QuestDefinition in all_quests():
		if not quest.is_active():
			continue
		var changed: bool = false
		for objective: QuestObjective in quest.objectives:
			if not _matches(objective.type, objective.target, event_type, event_target):
				continue
			if objective.raise_to(value):
				changed = true
		if changed:
			_after_progress(quest)


func _dispatch_failure(event_type: String, event_target: String) -> void:
	for quest: QuestDefinition in all_quests():
		if not quest.is_active() or quest.fail_type.is_empty():
			continue
		if _matches(quest.fail_type, quest.fail_target, event_type, event_target):
			_fail_quest(quest)


func _matches(
	objective_type: String, objective_target: String,
	event_type: String, event_target: String
) -> bool:
	if objective_type != event_type:
		return false
	return objective_target.is_empty() or objective_target == event_target


## Seats currently held by seated patrons.
func _occupied_seat_count() -> int:
	var count: int = 0
	for seat: Seat in SeatRegistry.all_seats(self):
		var patron: PatronNPC = seat.occupant as PatronNPC
		if patron != null and is_instance_valid(patron) and patron.is_sitting:
			count += 1
	return count


func _after_progress(quest: QuestDefinition) -> void:
	quest_progressed.emit(quest)
	if quest.all_objectives_done():
		_complete_quest(quest)


func _complete_quest(quest: QuestDefinition) -> void:
	quest.status = QuestDefinition.Status.COMPLETED
	_apply_rewards(quest)
	quest_completed.emit(quest)
	EventBus.post_notification("Quest complete: %s" % quest.title)
	_refresh_unlocks()


func _fail_quest(quest: QuestDefinition) -> void:
	quest.status = QuestDefinition.Status.FAILED
	quest_failed.emit(quest)
	EventBus.post_notification("Quest failed: %s" % quest.title)


func _apply_rewards(quest: QuestDefinition) -> void:
	var rewards: Dictionary = quest.rewards
	var copper: int = int(rewards.get("copper", 0))
	if copper > 0:
		EconomyManager.earn(copper, EconomyManager.Category.QUEST, quest.title)
	var all_reputation: float = float(rewards.get("all_reputation", 0.0))
	if all_reputation != 0.0:
		ReputationManager.adjust_all(all_reputation)
	var per_race: Dictionary = rewards.get("reputation", {})
	for race_key: Variant in per_race:
		ReputationManager.adjust(StringName(str(race_key)), float(per_race[race_key]))
	var tension_relief: float = float(rewards.get("tension_relief", 0.0))
	if tension_relief > 0.0:
		TensionManager.reduce_tension(tension_relief)
	for flag_key: Variant in rewards.get("flags", []):
		StoryManager.set_flag(StringName(str(flag_key)))


# --- Unlocking -----------------------------------------------------------------------


func _refresh_unlocks() -> void:
	var unlocked_any: bool = true
	while unlocked_any:
		unlocked_any = false
		for quest: QuestDefinition in all_quests():
			if quest.status != QuestDefinition.Status.LOCKED:
				continue
			if not _prerequisites_met(quest):
				continue
			quest.status = QuestDefinition.Status.ACTIVE
			_seed_threshold_objectives(quest)
			quest_started.emit(quest)
			EventBus.post_notification("New quest: %s" % quest.title)
			unlocked_any = true


## Threshold objectives start at the current world value, so a quest that
## unlocks when its condition already holds completes immediately.
func _seed_threshold_objectives(quest: QuestDefinition) -> void:
	var changed: bool = false
	for objective: QuestObjective in quest.objectives:
		if not THRESHOLD_TYPES.has(objective.type):
			continue
		var value: int = 0
		match objective.type:
			"funds_reach":
				value = GameManager.funds_copper
			"reputation_reach":
				value = int(ReputationManager.get_reputation(
					StringName(objective.target)
				))
			_:
				continue
		if objective.raise_to(value):
			changed = true
	if changed:
		_after_progress(quest)


func _prerequisites_met(quest: QuestDefinition) -> bool:
	for prereq_id: StringName in quest.prereq_quests:
		var prereq: QuestDefinition = get_quest(prereq_id)
		if prereq == null or prereq.status != QuestDefinition.Status.COMPLETED:
			return false
	for flag: StringName in quest.prereq_flags:
		if not StoryManager.has_flag(flag):
			return false
	return true


func _load_quests() -> void:
	var file: FileAccess = FileAccess.open(QUESTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("QuestManager: cannot open %s" % QUESTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_warning("QuestManager: %s is not a JSON object" % QUESTS_PATH)
		return
	for quest_source: Variant in (parsed as Dictionary).get("quests", []):
		if not quest_source is Dictionary:
			continue
		var quest: QuestDefinition = QuestDefinition.from_dict(quest_source)
		if quest == null:
			push_warning("QuestManager: malformed quest entry skipped")
			continue
		_quests[quest.id] = quest
		_quest_order.append(quest.id)
	print("QuestManager: loaded %d quests" % _quests.size())
