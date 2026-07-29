class_name DialogueLibrary
extends RefCounted
## Loads and serves NPC dialogue lines from external JSON data files.
##
## Lines are grouped by [i]moment[/i] (greeting, ordering, waiting, ...) and
## then by race id, with a "default" fallback per moment. Content lives in
## [code]res://data/dialogue/*.json[/code] so writers can edit it without
## touching code. All lookups are static; files are parsed once on first use.

const PATRON_LINES_PATH: String = "res://data/dialogue/patron_lines.json"
const STAFF_LINES_PATH: String = "res://data/dialogue/staff_lines.json"
const DEFAULT_KEY: String = "default"

## Patron dialogue moments (JSON top-level keys).
const MOMENT_GREETING: String = "greeting"
const MOMENT_ORDERING: String = "ordering"
const MOMENT_WAITING: String = "waiting"
const MOMENT_SERVED: String = "served"
const MOMENT_SATISFIED: String = "satisfied"
const MOMENT_ANGRY: String = "angry"
const MOMENT_CONFLICT: String = "conflict"
const MOMENT_LEAVING: String = "leaving"
const MOMENT_TOAST: String = "toast"
const MOMENT_GOSSIP: String = "gossip"
const MOMENT_SECOND: String = "second"
const MOMENT_SKIM: String = "skim"
const MOMENT_CHILL: String = "chill"

## Staff dialogue moments.
const MOMENT_SERVE_DRINK: String = "serve_drink"
const MOMENT_SERVE_FOOD: String = "serve_food"
const MOMENT_BREAKUP: String = "breakup"
const MOMENT_PERFORM: String = "perform"
const MOMENT_WORK_IDLE: String = "work_idle"

static var _patron_lines: Dictionary = {}
static var _staff_lines: Dictionary = {}
static var _loaded: bool = false


## Random patron line for [param moment], preferring [param race_id] entries
## and falling back to the moment's default pool. Empty when the moment has
## no lines for this race at all (used for race-exclusive moments).
static func patron_line(moment: String, race_id: StringName) -> String:
	_ensure_loaded()
	return _pick(_patron_lines, moment, String(race_id))


## Random staff line for [param moment].
static func staff_line(moment: String) -> String:
	_ensure_loaded()
	return _pick(_staff_lines, moment, DEFAULT_KEY)


## True when [param moment] has lines specifically authored for [param race_id].
static func has_race_lines(moment: String, race_id: StringName) -> bool:
	_ensure_loaded()
	var pools: Dictionary = _patron_lines.get(moment, {})
	return pools.has(String(race_id))


static func _pick(source: Dictionary, moment: String, preferred_key: String) -> String:
	var pools: Dictionary = source.get(moment, {})
	if pools.is_empty():
		return ""
	var lines: Array = pools.get(preferred_key, [])
	if lines.is_empty():
		lines = pools.get(DEFAULT_KEY, [])
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_patron_lines = _parse_file(PATRON_LINES_PATH)
	_staff_lines = _parse_file(STAFF_LINES_PATH)


static func _parse_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("DialogueLibrary: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_warning("DialogueLibrary: %s is not a JSON object" % path)
		return {}
	return parsed as Dictionary
