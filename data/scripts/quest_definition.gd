class_name QuestDefinition
extends RefCounted
## A full quest: identity, gating, objectives, failure trigger, and rewards.
##
## Parsed from [code]res://data/quests/quests.json[/code] by
## [code]QuestManager[/code]. All objectives must be done to complete;
## a matching fail event while active fails the quest permanently.

enum Status {
	LOCKED,
	ACTIVE,
	COMPLETED,
	FAILED,
}

var id: StringName = &""
var title: String = ""
var description: String = ""

## Story act this quest belongs to (1-3), for journal grouping.
var act: int = 1

## Quest ids that must be COMPLETED before this one activates.
var prereq_quests: Array[StringName] = []

## Story flags that must be set before this one activates.
var prereq_flags: Array[StringName] = []

var objectives: Array[QuestObjective] = []

## Event type that fails this quest while active ("" = cannot fail).
var fail_type: String = ""

## Optional filter for the fail event.
var fail_target: String = ""

## Reward payload: copper, all_reputation, reputation{race: delta},
## flags[], grant_upgrades[], tension_relief.
var rewards: Dictionary = {}

var status: Status = Status.LOCKED


func is_active() -> bool:
	return status == Status.ACTIVE


func all_objectives_done() -> bool:
	for objective: QuestObjective in objectives:
		if not objective.is_done():
			return false
	return true


## Parses one quest entry from JSON. Returns null on malformed data.
static func from_dict(source: Dictionary) -> QuestDefinition:
	var quest: QuestDefinition = QuestDefinition.new()
	quest.id = StringName(str(source.get("id", "")))
	quest.title = str(source.get("title", ""))
	if quest.id == &"" or quest.title.is_empty():
		return null
	quest.description = str(source.get("description", ""))
	quest.act = clampi(int(source.get("act", 1)), 1, 3)
	for quest_key: Variant in source.get("prereq_quests", []):
		quest.prereq_quests.append(StringName(str(quest_key)))
	for flag_key: Variant in source.get("prereq_flags", []):
		quest.prereq_flags.append(StringName(str(flag_key)))
	for objective_source: Variant in source.get("objectives", []):
		if not objective_source is Dictionary:
			continue
		var objective_dict: Dictionary = objective_source
		var objective: QuestObjective = QuestObjective.new()
		objective.type = str(objective_dict.get("type", ""))
		objective.target = str(objective_dict.get("target", ""))
		objective.required = maxi(1, int(objective_dict.get("count", 1)))
		objective.label = str(objective_dict.get("label", ""))
		if not objective.type.is_empty():
			quest.objectives.append(objective)
	if quest.objectives.is_empty():
		return null
	var fail_source: Dictionary = source.get("fail_on", {})
	quest.fail_type = str(fail_source.get("type", ""))
	quest.fail_target = str(fail_source.get("target", ""))
	quest.rewards = source.get("rewards", {})
	return quest
