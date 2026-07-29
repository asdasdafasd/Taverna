extends Node
## Bookkeeping for every coin that enters or leaves the tavern.
##
## All money mutation flows through [method earn] and [method try_spend]
## so the ledger stays complete; [code]GameManager.funds_copper[/code]
## remains the stored balance. Keeps a rolling entry history and per-day
## totals for the management screen. Charges wages and rent at day roll.
## Autoload name: [code]EconomyManager[/code].

## Emitted after any ledger entry is recorded.
signal ledger_updated(entry: LedgerEntry)

## Emitted when a daily charge (wages/rent) could not be paid in full.
signal payment_missed(category: Category, shortfall: int)

enum Category {
	SALE,
	TIP,
	WAGES,
	RENT,
	RESTOCK,
	REPAIR,
	UPGRADE,
	HOSPITALITY,
	LOSS,
}

const CATEGORY_NAMES: Dictionary[Category, String] = {
	Category.SALE: "Sale",
	Category.TIP: "Tip",
	Category.WAGES: "Wages",
	Category.RENT: "Rent",
	Category.RESTOCK: "Restock",
	Category.REPAIR: "Repairs",
	Category.UPGRADE: "Upgrade",
	Category.HOSPITALITY: "Hospitality",
	Category.LOSS: "Losses",
}

## Maximum entries kept in the rolling history.
const HISTORY_LIMIT: int = 200

## Daily fixed rent in copper.
const DAILY_RENT_COPPER: int = 45

## Group joined by staff NPCs so wages can be summed.
const STAFF_GROUP: StringName = &"staff"

var entries: Array[LedgerEntry] = []

## day -> [income, expenses] in copper.
var daily_totals: Dictionary[int, Vector2i] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	TimeManager.day_passed.connect(_on_day_passed)


## Records income and adds it to the tavern funds.
func earn(amount: int, category: Category, note: String = "") -> void:
	if amount <= 0:
		return
	GameManager.add_funds(amount)
	_record(amount, category, note)


## Attempts an expense; records it and returns true when affordable.
func try_spend(amount: int, category: Category, note: String = "") -> bool:
	if amount <= 0:
		return true
	if not GameManager.try_spend_funds(amount):
		return false
	_record(-amount, category, note)
	return true


## Books an unavoidable loss, draining funds down to zero if needed.
## Returns the copper that could not be covered.
func absorb_loss(amount: int, category: Category, note: String = "") -> int:
	if amount <= 0:
		return 0
	var covered: int = mini(amount, GameManager.funds_copper)
	if covered > 0:
		GameManager.try_spend_funds(covered)
		_record(-covered, category, note)
	return amount - covered


## Total daily wages owed to the current staff roster.
func total_daily_wages() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(STAFF_GROUP):
		var staff: StaffNPC = node as StaffNPC
		if staff != null:
			total += staff.wage_copper
	return total


## Income/expense pair for [param day] (zeroes when nothing was booked).
func totals_for_day(day: int) -> Vector2i:
	return daily_totals.get(day, Vector2i.ZERO)


## The most recent [param count] entries, newest first.
func recent_entries(count: int) -> Array[LedgerEntry]:
	var result: Array[LedgerEntry] = []
	var start: int = maxi(0, entries.size() - count)
	for index: int in range(entries.size() - 1, start - 1, -1):
		result.append(entries[index])
	return result


## SaveManager participant hook: persists per-day totals.
func write_save_data(data: SaveData) -> void:
	data.ledger_days.clear()
	for day: int in daily_totals:
		var totals: Vector2i = daily_totals[day]
		data.ledger_days[str(day)] = [totals.x, totals.y]


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	daily_totals.clear()
	entries.clear()
	for day_key: String in data.ledger_days:
		var pair: Array = data.ledger_days[day_key]
		if pair.size() == 2:
			daily_totals[int(day_key)] = Vector2i(int(pair[0]), int(pair[1]))


func _record(amount: int, category: Category, note: String) -> void:
	var entry: LedgerEntry = LedgerEntry.new()
	entry.day = TimeManager.day
	entry.hour = TimeManager.hour
	entry.minute = TimeManager.minute
	entry.amount = amount
	entry.category = category
	entry.note = note
	entries.append(entry)
	if entries.size() > HISTORY_LIMIT:
		entries.pop_front()
	var totals: Vector2i = daily_totals.get(entry.day, Vector2i.ZERO)
	if amount >= 0:
		totals.x += amount
	else:
		totals.y += -amount
	daily_totals[entry.day] = totals
	ledger_updated.emit(entry)


func _on_day_passed(_day: int) -> void:
	_charge_daily(total_daily_wages(), Category.WAGES, "daily staff wages")
	_charge_daily(DAILY_RENT_COPPER, Category.RENT, "daily rent")


func _charge_daily(amount: int, category: Category, note: String) -> void:
	if amount <= 0:
		return
	var shortfall: int = absorb_loss(amount, category, note)
	if shortfall > 0:
		payment_missed.emit(category, shortfall)
		TensionManager.add_tension(15.0, "unpaid %s" % CATEGORY_NAMES[category])
		ReputationManager.adjust_all(-3.0)
		EventBus.post_notification(
			"You are short %s for %s!" % [
				StringUtils.format_coins(shortfall), CATEGORY_NAMES[category],
			]
		)
