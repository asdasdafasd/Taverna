extends Node
## Persists and restores game state to JSON save slots on disk.
##
## Any node that joins [constant SAVE_GROUP] and implements
## [code]write_save_data(data: SaveData)[/code] /
## [code]read_save_data(data: SaveData)[/code] participates in saves.
## Autoload name: [code]SaveManager[/code].

## Emitted after a save succeeds or fails.
signal save_completed(success: bool, path: String)

## Emitted after a load succeeds or fails.
signal load_completed(success: bool, path: String)

## Group joined by nodes that contribute to / restore from save data.
const SAVE_GROUP: StringName = &"save_participants"

const SAVE_DIRECTORY: String = "user://saves"
const QUICKSAVE_SLOT: String = "quicksave"

## Where the keeper stands on a brand-new game (matches main.tscn).
const NEW_GAME_PLAYER_SPAWN: Vector3 = Vector3(1.3, 0.1, 4.2)

var _play_time_seconds: float = 0.0


func _ready() -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("SaveManager: could not create %s (error %d)" % [SAVE_DIRECTORY, error])


func _process(delta: float) -> void:
	_play_time_seconds += delta


## Collects state from all save participants and writes it to [param slot].
## The write is atomic: data lands in a temp file first, the previous save
## becomes a .bak, and only then is the temp renamed into place.
## Returns true on success.
func save_game(slot: String = QUICKSAVE_SLOT) -> bool:
	var data: SaveData = SaveData.new()
	data.saved_at = Time.get_datetime_string_from_system(true)
	data.play_time_seconds = _play_time_seconds
	data.day = TimeManager.day
	data.hour = TimeManager.hour
	data.minute = TimeManager.minute
	for participant: Node in get_tree().get_nodes_in_group(SAVE_GROUP):
		participant.write_save_data(data)
	var path: String = _slot_path(slot)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open %s for writing" % temp_path)
		save_completed.emit(false, path)
		return false
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	# Rotate: current save becomes the backup, temp becomes current.
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".bak")
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		push_warning("SaveManager: could not finalize %s (error %d)" % [
			path, rename_error,
		])
		save_completed.emit(false, path)
		return false
	save_completed.emit(true, path)
	EventBus.game_saved.emit(path)
	return true


## Reads [param slot] from disk and applies it to all save participants.
## Falls back to the .bak copy when the primary file is corrupt.
## Returns true on success.
func load_game(slot: String = QUICKSAVE_SLOT) -> bool:
	var path: String = _slot_path(slot)
	var data: SaveData = _read_slot(path)
	if data == null:
		data = _read_slot(path + ".bak")
		if data != null:
			push_warning("SaveManager: primary save unreadable; using backup")
	if data == null:
		load_completed.emit(false, path)
		return false
	_play_time_seconds = data.play_time_seconds
	TimeManager.set_clock(data.day, data.hour, data.minute)
	for participant: Node in get_tree().get_nodes_in_group(SAVE_GROUP):
		participant.read_save_data(data)
	load_completed.emit(true, path)
	EventBus.game_loaded.emit(path)
	return true


## Parses one save file into a SaveData, or null on any failure.
func _read_slot(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open %s for reading" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_warning("SaveManager: %s is not valid JSON" % path)
		return null
	var data: SaveData = SaveData.new()
	if not data.from_dict(parsed as Dictionary):
		push_warning("SaveManager: %s has an incompatible version" % path)
		return null
	return data


## True when [param slot] (or its backup) exists on disk.
func has_save(slot: String = QUICKSAVE_SLOT) -> bool:
	var path: String = _slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Resets every save participant to a fresh-game baseline by applying a
## default payload. Used when starting a new game from the main menu so no
## state leaks from a previous session (managers are autoloads).
func apply_new_game_state() -> void:
	var data: SaveData = SaveData.new()
	data.gold_copper = GameManager.STARTING_FUNDS_COPPER
	data.player_position = NEW_GAME_PLAYER_SPAWN
	_play_time_seconds = 0.0
	TimeManager.set_clock(data.day, data.hour, data.minute)
	for participant: Node in get_tree().get_nodes_in_group(SAVE_GROUP):
		participant.read_save_data(data)


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIRECTORY, slot]
