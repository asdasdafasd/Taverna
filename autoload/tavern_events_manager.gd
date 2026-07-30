extends Node
## Rolls and resolves random tavern events from an external data table.
##
## Events live in [code]res://data/events/events.json[/code] with weights,
## per-event day cooldowns, and tavern-state conditions (hour windows,
## patron counts, races present, funds, stock, story act). A roll happens
## every in-game hour; effects apply immediately through the economy,
## tension, reputation, and inventory managers.
## Autoload name: [code]TavernEventsManager[/code].

## Emitted when an event fires (after its effects are applied).
signal event_fired(event_id: StringName, title: String, text: String)

const EVENTS_PATH: String = "res://data/events/events.json"

## Chance that any event at all fires on a given hourly roll.
const HOURLY_TRIGGER_CHANCE: float = 0.35

var _events: Array[Dictionary] = []

## Event id -> in-game day it last fired (drives cooldowns).
var _last_fired_day: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_load_events()
	TimeManager.hour_passed.connect(_on_hour_passed)


## Number of loaded event definitions (for diagnostics/UI).
func event_count() -> int:
	return _events.size()


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.event_history.clear()
	for event_id: StringName in _last_fired_day:
		data.event_history[String(event_id)] = _last_fired_day[event_id]


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	_last_fired_day.clear()
	for event_key: String in data.event_history:
		_last_fired_day[StringName(event_key)] = int(data.event_history[event_key])


func _on_hour_passed(_day: int, _hour: int) -> void:
	if get_tree().paused:
		return
	if randf() > HOURLY_TRIGGER_CHANCE:
		return
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	for event: Dictionary in _events:
		if _is_eligible(event):
			candidates.append(event)
			total_weight += float(event.get("weight", 1.0))
	if candidates.is_empty() or total_weight <= 0.0:
		return
	var roll: float = randf() * total_weight
	for event: Dictionary in candidates:
		roll -= float(event.get("weight", 1.0))
		if roll <= 0.0:
			_fire(event)
			return


func _is_eligible(event: Dictionary) -> bool:
	var event_id: StringName = StringName(str(event.get("id", "")))
	var cooldown: int = int(event.get("cooldown_days", 0))
	if _last_fired_day.has(event_id):
		if TimeManager.day - _last_fired_day[event_id] < cooldown:
			return false
	return _conditions_hold(event.get("conditions", {}))


func _conditions_hold(conditions: Dictionary) -> bool:
	var ok: bool = true
	if conditions.has("hours"):
		var hours: Array = conditions["hours"]
		ok = ok and (
			hours.has(float(TimeManager.hour)) or hours.has(TimeManager.hour)
		)
	if ok and conditions.has("min_patrons"):
		ok = _seated_patrons().size() >= int(conditions["min_patrons"])
	if ok and conditions.has("race_present"):
		ok = _is_race_present(StringName(str(conditions["race_present"])))
	if ok and conditions.has("min_funds"):
		ok = GameManager.funds_copper >= int(conditions["min_funds"])
	if ok and conditions.has("min_stock"):
		ok = _total_stock() >= int(conditions["min_stock"])
	if ok and conditions.has("min_act"):
		ok = StoryManager.act() >= int(conditions["min_act"])
	return ok


func _fire(event: Dictionary) -> void:
	var event_id: StringName = StringName(str(event.get("id", "")))
	var title: String = str(event.get("title", ""))
	var text: String = str(event.get("text", ""))
	_last_fired_day[event_id] = TimeManager.day
	_apply_effects(event.get("effects", {}), title)
	event_fired.emit(event_id, title, text)
	EventBus.post_notification("%s — %s" % [title, text])


func _apply_effects(effects: Dictionary, title: String) -> void:
	var copper: int = int(effects.get("copper", 0))
	if copper > 0:
		EconomyManager.earn(copper, EconomyManager.Category.EVENT, title)
	elif copper < 0:
		EconomyManager.absorb_loss(-copper, EconomyManager.Category.EVENT, title)
	var tension: float = float(effects.get("tension", 0.0))
	if tension > 0.0:
		TensionManager.add_tension(tension, title)
	elif tension < 0.0:
		TensionManager.reduce_tension(-tension)
	var all_reputation: float = float(effects.get("all_reputation", 0.0))
	if all_reputation != 0.0:
		ReputationManager.adjust_all(all_reputation)
	var per_race: Dictionary = effects.get("reputation", {})
	for race_key: Variant in per_race:
		ReputationManager.adjust(StringName(str(race_key)), float(per_race[race_key]))
	_apply_stock_change(effects.get("stock_loss", {}), -1)
	_apply_stock_change(effects.get("stock_gain", {}), 1)


func _apply_stock_change(change: Dictionary, direction: int) -> void:
	if change.is_empty():
		return
	var item_id: StringName = StringName(str(change.get("item", "")))
	var units: int = maxi(0, int(change.get("units", 0)))
	if item_id == &"" or units == 0:
		return
	if direction > 0:
		for _unit: int in units:
			InventoryManager.return_unit(item_id)
	else:
		for _unit: int in units:
			if not InventoryManager.try_consume(item_id):
				break


func _seated_patrons() -> Array[PatronNPC]:
	var patrons: Array[PatronNPC] = []
	for seat: Seat in SeatRegistry.all_seats(self):
		var patron: PatronNPC = seat.occupant as PatronNPC
		if patron != null and is_instance_valid(patron) and patron.is_sitting:
			patrons.append(patron)
	return patrons


func _is_race_present(race_id: StringName) -> bool:
	for patron: PatronNPC in _seated_patrons():
		if patron.race.id == race_id:
			return true
	return false


func _total_stock() -> int:
	var total: int = 0
	for item_id: StringName in InventoryManager.servable_item_ids():
		total += InventoryManager.stock_of(item_id)
	return total


func _load_events() -> void:
	var file: FileAccess = FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("TavernEventsManager: cannot open %s" % EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_warning("TavernEventsManager: %s is not a JSON object" % EVENTS_PATH)
		return
	for event_source: Variant in (parsed as Dictionary).get("events", []):
		if event_source is Dictionary and str(
			(event_source as Dictionary).get("id", "")
		) != "":
			_events.append(event_source)
	print("TavernEventsManager: loaded %d events" % _events.size())
