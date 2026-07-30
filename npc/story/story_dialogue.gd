class_name StoryDialogue
extends RefCounted
## Loads staged story-character dialogue from JSON and selects the stage
## that matches the current story flags.
##
## Each character has ambient one-liners plus an ordered list of stages;
## a stage matches when all its [code]if_flags_all[/code] are set and none
## of its [code]if_flags_none[/code] are. The first matching stage wins, so
## authors order stages from most to least specific.

const DIALOGUE_PATH: String = "res://data/dialogue/story_dialogue.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


## A random ambient bubble line for [param character_id] ("" when none).
static func ambient_line(character_id: StringName) -> String:
	_ensure_loaded()
	var character: Dictionary = _data.get(String(character_id), {})
	var lines: Array = character.get("ambient", [])
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


## The highest-priority stage whose flag conditions currently hold.
## Returns an empty Dictionary when the character has no matching stage.
static func stage_for(character_id: StringName) -> Dictionary:
	_ensure_loaded()
	var character: Dictionary = _data.get(String(character_id), {})
	for stage_source: Variant in character.get("stages", []):
		if not stage_source is Dictionary:
			continue
		var stage: Dictionary = stage_source
		if _stage_matches(stage):
			return stage
	return {}


static func _stage_matches(stage: Dictionary) -> bool:
	for flag_key: Variant in stage.get("if_flags_all", []):
		if not StoryManager.has_flag(StringName(str(flag_key))):
			return false
	for flag_key: Variant in stage.get("if_flags_none", []):
		if StoryManager.has_flag(StringName(str(flag_key))):
			return false
	return true


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_warning("StoryDialogue: cannot open %s" % DIALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("StoryDialogue: %s is not a JSON object" % DIALOGUE_PATH)
