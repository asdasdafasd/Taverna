extends Node
## Single source of truth for narrative state: story flags, the current
## act, and the player's Accord decision.
##
## The arc: the player inherits The Wandering Flagon from their grandfather
## Aldous and slowly uncovers what the building really is — the buried
## truce-hall where the seven peoples once signed the Accord that keeps the
## valley's peace. Act 3 asks the player to renew that pact or let it fade.
## Flags are raised by quests, dialogue, and world markers; everything else
## (QuestManager, StoryDirector, events) reads from here.
## Autoload name: [code]StoryManager[/code].

## Emitted when a new flag is raised (first time only).
signal flag_raised(flag: StringName)

## Emitted when the story advances to a new act.
signal act_changed(act: int)

enum AccordChoice {
	UNDECIDED,
	RENEWED,
	FADED,
}

## Flags that push the arc into act 2 / act 3 when raised.
const ACT2_FLAG: StringName = &"act1_letter"
const ACT3_FLAG: StringName = &"met_vess"

var accord_choice: AccordChoice = AccordChoice.UNDECIDED

var _flags: Dictionary[StringName, bool] = {}
var _act: int = 1


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)


## Current story act (1-3).
func act() -> int:
	return _act


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


## Raises [param flag]; no-op when already set.
func set_flag(flag: StringName) -> void:
	if flag == &"" or has_flag(flag):
		return
	_flags[flag] = true
	flag_raised.emit(flag)
	EventBus.story_flag_set.emit(flag)
	_update_act()


## All raised flags (for saves and debugging).
func all_flags() -> Array[StringName]:
	var result: Array[StringName] = []
	for flag: StringName in _flags:
		if _flags[flag]:
			result.append(flag)
	return result


## Records the player's act-3 decision and raises the shared choice flag.
func make_accord_choice(renewed: bool) -> void:
	if accord_choice != AccordChoice.UNDECIDED:
		return
	accord_choice = AccordChoice.RENEWED if renewed else AccordChoice.FADED
	if renewed:
		set_flag(&"accord_renewed")
		# Renewing the pact steadies the whole valley's mood.
		TensionManager.reduce_tension(25.0)
		ReputationManager.adjust_all(4.0)
	else:
		set_flag(&"accord_faded")
		# Letting it fade frees the binding coin Aldous paid each season.
		EconomyManager.earn(
			120, EconomyManager.Category.QUEST, "the Accord's binding coin, unspent"
		)
	set_flag(&"accord_choice_made")


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.story_flags.clear()
	for flag: StringName in all_flags():
		data.story_flags.append(String(flag))
	data.accord_choice = accord_choice


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	_flags.clear()
	_act = 1
	accord_choice = clampi(
		data.accord_choice, AccordChoice.UNDECIDED, AccordChoice.FADED
	) as AccordChoice
	for flag_key: String in data.story_flags:
		_flags[StringName(flag_key)] = true
	_update_act()


func _update_act() -> void:
	var new_act: int = 1
	if has_flag(ACT3_FLAG):
		new_act = 3
	elif has_flag(ACT2_FLAG):
		new_act = 2
	if new_act != _act:
		_act = new_act
		act_changed.emit(_act)
		EventBus.post_notification("Act %d begins." % _act)
