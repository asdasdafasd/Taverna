extends Node
## Orchestrates brawls: escalation, bystander reactions, furniture damage,
## and the recovery back to a calm room.
##
## Patrons still fight each other directly ([code]PatronNPC[/code] owns the
## FIGHTING state); this manager tracks active fights, rolls bystander
## join/flee reactions, books furniture damage over time, and offers the
## intervention API used by the bouncer and the player.
## Autoload name: [code]BrawlManager[/code].

## Emitted when the number of active fights changes.
signal active_brawl_count_changed(count: int)

## Emitted when furniture damage from a brawl is booked.
signal furniture_damaged(cost_copper: int)

## Copper of furniture damage per fighting pair per damage tick.
const DAMAGE_PER_TICK_COPPER: int = 3

## Seconds between brawl damage ticks.
const DAMAGE_TICK_SECONDS: float = 2.0

## Tension added when a brawl starts / while one rages per tick.
const TENSION_ON_START: float = 18.0
const TENSION_PER_TICK: float = 2.0

## Radius around a fight that bystanders react to.
const REACTION_RADIUS: float = 4.0

## Chance rolls for bystander reactions, scaled by race temperament.
const JOIN_CHANCE_BASE: float = 0.25
const FLEE_CHANCE_BASE: float = 0.5

## Reputation cost per brawl for the races involved.
const REPUTATION_COST: float = 4.0

## Calming-word intervention: tension relief and success odds.
const CALM_TENSION_RELIEF: float = 12.0
const CALM_SUCCESS_CHANCE: float = 0.55

## Accumulated unrepaired damage, in copper.
var damage_owed_copper: int = 0

var _active_pairs: Array[Array] = []
var _damage_timer: Timer = null
var _reactions_rolled: Dictionary[PatronNPC, bool] = {}


func _ready() -> void:
	add_to_group(SaveManager.SAVE_GROUP)
	_damage_timer = Timer.new()
	_damage_timer.name = "DamageTimer"
	_damage_timer.wait_time = DAMAGE_TICK_SECONDS
	_damage_timer.one_shot = false
	_damage_timer.autostart = true
	add_child(_damage_timer)
	_damage_timer.timeout.connect(_on_damage_tick)
	EventBus.brawl_started.connect(_on_brawl_started)
	EventBus.brawl_ended.connect(_on_brawl_ended)


## Number of currently raging fights.
func active_brawl_count() -> int:
	return _active_pairs.size()


func has_active_brawl() -> bool:
	return not _active_pairs.is_empty()


## All patrons currently in a tracked fight.
func active_fighters() -> Array[PatronNPC]:
	var fighters: Array[PatronNPC] = []
	for pair: Array in _active_pairs:
		for fighter: Variant in pair:
			var patron: PatronNPC = fighter as PatronNPC
			if patron != null and is_instance_valid(patron):
				fighters.append(patron)
	return fighters


## Forceful breakup (bouncer or player shove): both fighters storm out.
## Returns true when a fight was actually stopped.
func break_up_nearest(position: Vector3) -> bool:
	var fighter: PatronNPC = _nearest_fighter(position)
	if fighter == null:
		return false
	fighter.break_up_fight()
	return true


## Diplomatic intervention (player buying a round of calming words):
## may end the nearest fight peacefully and always vents some tension.
## Returns true when the fight dissolved.
func try_calm_nearest(position: Vector3) -> bool:
	var fighter: PatronNPC = _nearest_fighter(position)
	if fighter == null:
		return false
	TensionManager.reduce_tension(CALM_TENSION_RELIEF)
	if randf() > CALM_SUCCESS_CHANCE:
		return false
	fighter.calm_down_from_fight()
	return true


## Pays off all accumulated furniture damage. Returns false when broke.
func try_repair_damage() -> bool:
	if damage_owed_copper <= 0:
		return true
	if not EconomyManager.try_spend(
		damage_owed_copper, EconomyManager.Category.REPAIR, "furniture repairs"
	):
		return false
	damage_owed_copper = 0
	furniture_damaged.emit(0)
	return true


## SaveManager participant hook.
func write_save_data(data: SaveData) -> void:
	data.furniture_damage_copper = damage_owed_copper


## SaveManager participant hook.
func read_save_data(data: SaveData) -> void:
	damage_owed_copper = data.furniture_damage_copper
	furniture_damaged.emit(damage_owed_copper)


func _on_brawl_started(initiator: PatronNPC, target: PatronNPC) -> void:
	_active_pairs.append([initiator, target])
	active_brawl_count_changed.emit(active_brawl_count())
	TensionManager.add_tension(TENSION_ON_START, "a brawl broke out")
	ReputationManager.adjust(initiator.race.id, -REPUTATION_COST)
	ReputationManager.adjust(target.race.id, -REPUTATION_COST)
	_roll_bystander_reactions(initiator, target)
	EventBus.post_notification(
		"%s and %s are brawling!" % [initiator.npc_name, target.npc_name]
	)


func _on_brawl_ended(initiator: PatronNPC, target: PatronNPC) -> void:
	for index: int in range(_active_pairs.size() - 1, -1, -1):
		var pair: Array = _active_pairs[index]
		if pair.has(initiator) or pair.has(target):
			_active_pairs.remove_at(index)
	active_brawl_count_changed.emit(active_brawl_count())


func _on_damage_tick() -> void:
	if get_tree().paused:
		return
	_prune_dead_pairs()
	if _active_pairs.is_empty():
		return
	var reduction: float = clampf(
		UpgradeManager.effect_value(&"brawl_damage_reduction"), 0.0, 0.9
	)
	var per_pair: int = maxi(
		1, int(round(DAMAGE_PER_TICK_COPPER * (1.0 - reduction)))
	)
	var damage: int = per_pair * _active_pairs.size()
	damage_owed_copper += damage
	furniture_damaged.emit(damage_owed_copper)
	TensionManager.add_tension(TENSION_PER_TICK * float(_active_pairs.size()))


func _roll_bystander_reactions(initiator: PatronNPC, target: PatronNPC) -> void:
	var center: Vector3 = (
		initiator.global_position + target.global_position
	) * 0.5
	for seat: Seat in SeatRegistry.all_seats(self):
		var bystander: PatronNPC = seat.occupant as PatronNPC
		if bystander == null or not is_instance_valid(bystander):
			continue
		if bystander == initiator or bystander == target:
			continue
		if _reactions_rolled.get(bystander, false):
			continue
		if bystander.global_position.distance_to(center) > REACTION_RADIUS:
			continue
		if not bystander.can_be_drawn_into_brawl():
			continue
		_reactions_rolled[bystander] = true
		_roll_single_reaction(bystander, initiator, target)
	_reactions_rolled.clear()


func _roll_single_reaction(
	bystander: PatronNPC, initiator: PatronNPC, target: PatronNPC
) -> void:
	var race: RaceData = bystander.race
	# Allies of a fighter with aggressive blood may pile in.
	var joins_side: PatronNPC = null
	if race.is_ally_of(initiator.race.id) or race.is_enemy_of(target.race.id):
		joins_side = target
	elif race.is_ally_of(target.race.id) or race.is_enemy_of(initiator.race.id):
		joins_side = initiator
	if joins_side != null and randf() < JOIN_CHANCE_BASE * race.aggression * 2.0:
		bystander.join_brawl(joins_side)
		# Deferred so the new pair's reaction roll cannot re-enter this loop.
		EventBus.brawl_started.emit.call_deferred(bystander, joins_side)
		return
	# Timid races flee the room instead.
	var flee_chance: float = FLEE_CHANCE_BASE * (1.0 - race.aggression)
	if randf() < flee_chance:
		bystander.flee_from_brawl()


func _nearest_fighter(position: Vector3) -> PatronNPC:
	var best: PatronNPC = null
	var best_distance: float = INF
	for fighter: PatronNPC in active_fighters():
		if fighter.state != PatronNPC.State.FIGHTING:
			continue
		var distance: float = position.distance_squared_to(fighter.global_position)
		if distance < best_distance:
			best_distance = distance
			best = fighter
	return best


func _prune_dead_pairs() -> void:
	for index: int in range(_active_pairs.size() - 1, -1, -1):
		var pair: Array = _active_pairs[index]
		var a: PatronNPC = pair[0] as PatronNPC
		var b: PatronNPC = pair[1] as PatronNPC
		var a_fighting: bool = (
			a != null and is_instance_valid(a)
			and a.state == PatronNPC.State.FIGHTING
		)
		var b_fighting: bool = (
			b != null and is_instance_valid(b)
			and b.state == PatronNPC.State.FIGHTING
		)
		if not a_fighting and not b_fighting:
			_active_pairs.remove_at(index)
			active_brawl_count_changed.emit(active_brawl_count())
