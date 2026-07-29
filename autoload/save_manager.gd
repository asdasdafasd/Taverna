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

var _play_time_seconds: float = 0.0


func _ready() -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("SaveManager: could not create %s (error %d)" % [SAVE_DIRECTORY, error])


func _process(delta: float) -> void:
	_play_time_seconds += delta


## Collects state from all save participants and writes it to [param slot].
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
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open %s for writing" % path)
		save_completed.emit(false, path)
		return false
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	save_completed.emit(true, path)
	EventBus.game_saved.emit(path)
	return true


## Reads [param slot] from disk and applies it to all save participants.
## Returns true on success.
func load_game(slot: String = QUICKSAVE_SLOT) -> bool:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		load_completed.emit(false, path)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open %s for reading" % path)
		load_completed.emit(false, path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_warning("SaveManager: %s is not valid JSON" % path)
		load_completed.emit(false, path)
		return false
	var data: SaveData = SaveData.new()
	if not data.from_dict(parsed as Dictionary):
		push_warning("SaveManager: %s has an incompatible version" % path)
		load_completed.emit(false, path)
		return false
	_play_time_seconds = data.play_time_seconds
	TimeManager.set_clock(data.day, data.hour, data.minute)
	for participant: Node in get_tree().get_nodes_in_group(SAVE_GROUP):
		participant.read_save_data(data)
	load_completed.emit(true, path)
	EventBus.game_loaded.emit(path)
	return true


## True when [param slot] exists on disk.
func has_save(slot: String = QUICKSAVE_SLOT) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIRECTORY, slot]
