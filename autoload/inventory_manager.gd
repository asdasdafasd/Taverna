extends Node
## Stock room and menu book: what the tavern can serve and at what price.
##
## Every servable item has a stock count and a player-set menu price.
## Orders reserve stock at placement and release it on cancellation; sales
## are booked through [EconomyManager] on delivery. Restocking buys units
## at the item's base value (minus upgrade discounts).
## Autoload name: [code]InventoryManager[/code].

## Emitted when an item's stock count changes.
signal stock_changed(item_id: StringName, units: int)

## Emitted when an item's menu price changes.
signal price_changed(item_id: StringName, price_copper: int)

## Emitted when the last unit of an item is used up.
signal item_sold_out(item_id: StringName)

const STARTING_STOCK_UNITS: int = 8
const RESTOCK_BATCH_UNITS: int = 5

## Default margin applied over base value for opening menu prices.
const DEFAULT_PRICE_MARGIN: float = 0.6

## Menu prices are clamped to base value * [1 - span, 1 + span... ] bounds.
const MIN_PRICE_FACTOR: float = 0.5
const MAX_PRICE_FACTOR: float = 3.0

## Price gouging beyond this factor of base value irritates patrons.
const GOUGING_FACTOR: float = 2.0

var _stock: Dictionary[StringName, int] = {}
var _prices: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_initialize_catalog.call_deferred()


## All item ids the tavern can put on the menu (drinks and food).
func servable_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemData in GameManager.get_all_items():
		if item.is_servable():
			result.append(item.id)
	result.sort()
	return result


func stock_of(item_id: StringName) -> int:
	return _stock.get(item_id, 0)


func has_stock(item_id: StringName) -> bool:
	return stock_of(item_id) > 0


## Current menu price in copper (base value when never set).
func price_of(item_id: StringName) -> int:
	if _prices.has(item_id):
		return _prices[item_id]
	var item: ItemData = GameManager.get_item(item_id)
	return item.base_value if item != null else 0


## Sets the menu price, clamped to sane bounds around base value.
func set_price(item_id: StringName, price_copper: int) -> void:
	var item: ItemData = GameManager.get_item(item_id)
	if item == null:
		return
	var min_price: int = maxi(1, int(floor(item.base_value * MIN_PRICE_FACTOR)))
	var max_price: int = maxi(min_price, int(ceil(item.base_value * MAX_PRICE_FACTOR)))
	var clamped: int = clampi(price_copper, min_price, max_price)
	if _prices.get(item_id, -1) == clamped:
		return
	_prices[item_id] = clamped
	price_changed.emit(item_id, clamped)


## True when the price sits in gouging territory (patrons resent it).
func is_gouging(item_id: StringName) -> bool:
	var item: ItemData = GameManager.get_item(item_id)
	if item == null or item.base_value <= 0:
		return false
	return float(price_of(item_id)) >= float(item.base_value) * GOUGING_FACTOR


## Reserves one unit for an order. Returns false when sold out.
func try_consume(item_id: StringName) -> bool:
	var units: int = stock_of(item_id)
	if units <= 0:
		return false
	_stock[item_id] = units - 1
	stock_changed.emit(item_id, units - 1)
	if units - 1 == 0:
		item_sold_out.emit(item_id)
	return true


## Returns one reserved unit (cancelled order).
func return_unit(item_id: StringName) -> void:
	_stock[item_id] = stock_of(item_id) + 1
	stock_changed.emit(item_id, _stock[item_id])


## Cost of one restock batch for [param item_id], after discounts.
func restock_cost(item_id: StringName) -> int:
	var item: ItemData = GameManager.get_item(item_id)
	if item == null:
		return 0
	var discount: float = clampf(
		UpgradeManager.effect_value(&"restock_discount"), 0.0, 0.9
	)
	var unit_cost: float = float(item.base_value) * (1.0 - discount)
	return maxi(1, int(ceil(unit_cost * float(RESTOCK_BATCH_UNITS))))


## Buys one batch of [param item_id]. Returns false when unaffordable.
func try_restock(item_id: StringName) -> bool:
	var item: ItemData = GameManager.get_item(item_id)
	if item == null:
		return false
	var cost: int = restock_cost(item_id)
	if not EconomyManager.try_spend(
		cost, EconomyManager.Category.RESTOCK,
		"%d x %s" % [RESTOCK_BATCH_UNITS, item.display_name]
	):
		return false
	_stock[item_id] = stock_of(item_id) + RESTOCK_BATCH_UNITS
	stock_changed.emit(item_id, _stock[item_id])
	EventBus.item_restocked.emit(item_id)
	return true


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.stock.clear()
	data.menu_prices.clear()
	for item_id: StringName in _stock:
		data.stock[String(item_id)] = _stock[item_id]
	for item_id: StringName in _prices:
		data.menu_prices[String(item_id)] = _prices[item_id]


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	for item_key: String in data.stock:
		var item_id: StringName = StringName(item_key)
		_stock[item_id] = maxi(0, int(data.stock[item_key]))
		stock_changed.emit(item_id, _stock[item_id])
	for item_key: String in data.menu_prices:
		set_price(StringName(item_key), int(data.menu_prices[item_key]))


func _initialize_catalog() -> void:
	for item_id: StringName in servable_item_ids():
		if not _stock.has(item_id):
			_stock[item_id] = STARTING_STOCK_UNITS
		if not _prices.has(item_id):
			var item: ItemData = GameManager.get_item(item_id)
			_prices[item_id] = maxi(
				1, int(round(item.base_value * (1.0 + DEFAULT_PRICE_MARGIN)))
			)
