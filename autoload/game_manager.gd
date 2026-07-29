extends Node
## Top-level session state and game data catalogs.
##
## Owns the play/pause state, the tavern's funds, and typed catalogs of item,
## recipe, and race definitions loaded from [code]res://data/[/code].
## Autoload name: [code]GameManager[/code].

## Emitted when the session moves between PLAYING and PAUSED.
signal state_changed(new_state: State)

## Emitted when the tavern's funds change.
signal funds_changed(copper_total: int)

enum State {
	BOOTING,
	PLAYING,
	PAUSED,
}

const ITEMS_DIRECTORY: String = "res://data/items"
const RECIPES_DIRECTORY: String = "res://data/recipes"
const RACES_DIRECTORY: String = "res://data/races"
const STARTING_FUNDS_COPPER: int = 250

var state: State = State.BOOTING

## Tavern funds in copper coins.
var funds_copper: int = STARTING_FUNDS_COPPER:
	set(value):
		funds_copper = maxi(0, value)
		funds_changed.emit(funds_copper)

var _items: Dictionary[StringName, ItemData] = {}
var _recipes: Dictionary[StringName, RecipeData] = {}
var _races: Dictionary[StringName, RaceData] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(SaveManager.SAVE_GROUP)
	_load_catalogs()
	_set_state(State.PLAYING)


## Pauses the scene tree and the in-game clock.
func pause_game() -> void:
	if state != State.PLAYING:
		return
	get_tree().paused = true
	TimeManager.clock_paused = true
	_set_state(State.PAUSED)


## Resumes from pause.
func resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	TimeManager.clock_paused = false
	_set_state(State.PLAYING)


func is_paused() -> bool:
	return state == State.PAUSED


## Adds coins to the tavern's funds.
func add_funds(copper_amount: int) -> void:
	funds_copper += maxi(0, copper_amount)


## Removes coins when affordable; returns false if funds are insufficient.
func try_spend_funds(copper_amount: int) -> bool:
	if copper_amount > funds_copper:
		return false
	funds_copper -= copper_amount
	return true


func get_item(item_id: StringName) -> ItemData:
	return _items.get(item_id)


func get_recipe(recipe_id: StringName) -> RecipeData:
	return _recipes.get(recipe_id)


func get_race(race_id: StringName) -> RaceData:
	return _races.get(race_id)


func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(_items.values())
	return result


func get_all_recipes() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	result.assign(_recipes.values())
	return result


func get_all_races() -> Array[RaceData]:
	var result: Array[RaceData] = []
	result.assign(_races.values())
	return result


## SaveManager participant hook: contributes session state to the payload.
func write_save_data(data: SaveData) -> void:
	data.gold_copper = funds_copper


## SaveManager participant hook: restores session state from the payload.
func read_save_data(data: SaveData) -> void:
	funds_copper = data.gold_copper


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _load_catalogs() -> void:
	for resource: Resource in _load_resources_in(ITEMS_DIRECTORY):
		var item: ItemData = resource as ItemData
		if item != null and item.id != &"":
			_items[item.id] = item
	for resource: Resource in _load_resources_in(RECIPES_DIRECTORY):
		var recipe: RecipeData = resource as RecipeData
		if recipe != null and recipe.is_valid():
			_recipes[recipe.id] = recipe
	for resource: Resource in _load_resources_in(RACES_DIRECTORY):
		var race: RaceData = resource as RaceData
		if race != null and race.id != &"":
			_races[race.id] = race
	print("GameManager: loaded %d items, %d recipes, %d races" % [
		_items.size(), _recipes.size(), _races.size(),
	])


func _load_resources_in(directory_path: String) -> Array[Resource]:
	var resources: Array[Resource] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		push_warning("GameManager: missing data directory %s" % directory_path)
		return resources
	for file_name: String in directory.get_files():
		# Exported builds list resources as ".tres.remap"; strip the suffix.
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var resource: Resource = load("%s/%s" % [directory_path, resource_name])
		if resource != null:
			resources.append(resource)
	return resources
