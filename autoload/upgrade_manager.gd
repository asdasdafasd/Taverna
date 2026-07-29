extends Node
## Owns the upgrade catalog and the set of purchased upgrades.
##
## Systems never reference upgrades directly; they ask
## [method effect_value] for summed named effects (e.g.
## [code]&"max_patrons_bonus"[/code]) so effects stack cleanly and new
## upgrades plug in via data alone. Autoload name: [code]UpgradeManager[/code].

## Emitted when an upgrade purchase completes.
signal upgrade_purchased(upgrade: UpgradeData)

const UPGRADES_DIRECTORY: String = "res://data/upgrades"

var _catalog: Dictionary[StringName, UpgradeData] = {}
var _owned: Dictionary[StringName, bool] = {}
var _effect_cache: Dictionary[StringName, float] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_load_catalog()


## Every upgrade definition, sorted by branch then cost.
func all_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	result.assign(_catalog.values())
	result.sort_custom(
		func(a: UpgradeData, b: UpgradeData) -> bool:
			if a.branch != b.branch:
				return a.branch < b.branch
			return a.cost_copper < b.cost_copper
	)
	return result


func get_upgrade(upgrade_id: StringName) -> UpgradeData:
	return _catalog.get(upgrade_id)


func is_owned(upgrade_id: StringName) -> bool:
	return _owned.get(upgrade_id, false)


## True when prerequisites are met and it is not already owned.
func can_purchase(upgrade_id: StringName) -> bool:
	var upgrade: UpgradeData = get_upgrade(upgrade_id)
	if upgrade == null or is_owned(upgrade_id):
		return false
	return upgrade.requires_id == &"" or is_owned(upgrade.requires_id)


## Buys the upgrade through the economy. Returns false when blocked or broke.
func try_purchase(upgrade_id: StringName) -> bool:
	if not can_purchase(upgrade_id):
		return false
	var upgrade: UpgradeData = get_upgrade(upgrade_id)
	if not EconomyManager.try_spend(
		upgrade.cost_copper, EconomyManager.Category.UPGRADE, upgrade.display_name
	):
		return false
	_grant(upgrade_id)
	EventBus.post_notification("Upgrade installed: %s" % upgrade.display_name)
	upgrade_purchased.emit(upgrade)
	return true


## Summed value of [param effect_key] across all owned upgrades (0 when none).
func effect_value(effect_key: StringName) -> float:
	return _effect_cache.get(effect_key, 0.0)


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.owned_upgrades.clear()
	for upgrade_id: StringName in _owned:
		if _owned[upgrade_id]:
			data.owned_upgrades.append(String(upgrade_id))


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	_owned.clear()
	for upgrade_key: String in data.owned_upgrades:
		var upgrade_id: StringName = StringName(upgrade_key)
		if _catalog.has(upgrade_id):
			_owned[upgrade_id] = true
	_rebuild_effect_cache()


func _grant(upgrade_id: StringName) -> void:
	_owned[upgrade_id] = true
	_rebuild_effect_cache()


func _rebuild_effect_cache() -> void:
	_effect_cache.clear()
	for upgrade_id: StringName in _owned:
		if not _owned[upgrade_id]:
			continue
		var upgrade: UpgradeData = _catalog.get(upgrade_id)
		if upgrade == null:
			continue
		for effect_key: StringName in upgrade.effects:
			_effect_cache[effect_key] = (
				_effect_cache.get(effect_key, 0.0) + upgrade.effects[effect_key]
			)


func _load_catalog() -> void:
	var directory: DirAccess = DirAccess.open(UPGRADES_DIRECTORY)
	if directory == null:
		push_warning("UpgradeManager: missing %s" % UPGRADES_DIRECTORY)
		return
	for file_name: String in directory.get_files():
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var upgrade: UpgradeData = load(
			"%s/%s" % [UPGRADES_DIRECTORY, resource_name]
		) as UpgradeData
		if upgrade != null and upgrade.id != &"":
			_catalog[upgrade.id] = upgrade
	print("UpgradeManager: loaded %d upgrades" % _catalog.size())
