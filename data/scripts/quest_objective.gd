class_name QuestObjective
extends RefCounted
## One trackable goal inside a quest.
##
## Objectives are matched against gameplay events by (type, target); an
## empty target matches any event of that type. Reach-type objectives
## (funds, reputation) treat [member required] as a threshold instead of a
## counter. Built by [code]QuestManager[/code] from quest JSON.

## Event routing key, e.g. "serve_orders", "talk_to", "funds_reach".
var type: String = ""

## Optional filter (race id, character id, marker id, upgrade id...).
var target: String = ""

## Count or threshold needed to satisfy the objective.
var required: int = 1

## Player-facing objective line.
var label: String = ""

## Current progress toward [member required].
var progress: int = 0


func is_done() -> bool:
	return progress >= required


## Adds to the counter (clamped) and reports whether anything changed.
func advance(amount: int) -> bool:
	if is_done() or amount <= 0:
		return false
	progress = mini(required, progress + amount)
	return true


## Sets threshold-style progress (funds/reputation levels).
func raise_to(value: int) -> bool:
	var clamped: int = clampi(value, 0, required)
	if clamped <= progress:
		return false
	progress = clamped
	return true


func progress_text() -> String:
	return "%s (%d/%d)" % [label, progress, required]
