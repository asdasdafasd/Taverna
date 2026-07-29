class_name PatronNPC
extends NPCBase
## A tavern guest: enters, claims a seat, orders, consumes, socializes,
## brawls when provoked, pays, and leaves.
##
## All decisions run in the timer-driven [method _think] loop with a strict
## priority order: danger first, then unmet needs, then service, then social
## behavior, then leaving. Movement completion is event-driven via
## [method _on_navigation_arrived].

## Emitted when the patron's lifecycle state changes.
signal state_changed(new_state: State)

enum State {
	ENTERING, ## Walking from spawn to the entrance interior point.
	FINDING_SEAT, ## Picking and claiming a chair.
	GOING_TO_SEAT, ## Walking to the claimed chair.
	SITTING, ## Seated, deciding what they need.
	WAITING_ORDER, ## Order placed, watching the counter.
	CONSUMING, ## Drink/meal in hand.
	SOCIALIZING, ## Lingering, gossiping, toasting.
	FIGHTING, ## Brawling with another patron.
	LEAVING, ## Walking to the exit; despawns on arrival.
}

# --- Needs tuning -----------------------------------------------------------
const THIRST_PER_SECOND: float = 0.02
const HUNGER_PER_SECOND: float = 0.012
const NEED_ORDER_THRESHOLD: float = 0.5
const CONSUME_SECONDS_DRINK: float = 14.0
const CONSUME_SECONDS_FOOD: float = 20.0
const NEED_SATISFIED_VALUE: float = 0.05

# --- Mood tuning -------------------------------------------------------------
const MOOD_START: float = 0.65
const MOOD_SERVED_BONUS: float = 0.2
const MOOD_FAVORITE_BONUS: float = 0.15
const MOOD_WAIT_PENALTY_PER_SECOND: float = 0.004
const MOOD_ENEMY_NEARBY_PENALTY: float = 0.06
const MOOD_ALLY_NEARBY_BONUS: float = 0.03
const MOOD_ANGRY_THRESHOLD: float = 0.2
const MOOD_HAPPY_THRESHOLD: float = 0.75
const NEIGHBOR_RADIUS: float = 2.2

# --- Social tuning -----------------------------------------------------------
const SOCIAL_LINGER_BASE_SECONDS: float = 8.0
const SOCIAL_LINGER_PER_SOCIABILITY: float = 22.0
const GOSSIP_CHANCE: float = 0.35
const CHILL_CHANCE: float = 0.25
const BRAWL_CHANCE_PER_THINK: float = 0.22
const BRAWL_SECONDS: float = 6.0
const CROWD_TOLERANCE_ALOOF: int = 2

# --- Payment ------------------------------------------------------------------
const TIP_BASE_FRACTION: float = 0.5
const GOBLIN_SKIM_CHANCE: float = 0.45
const GOBLIN_SKIM_FRACTION: float = 0.5

## Angry leavers storm out faster than they walked in.
const ANGRY_STRIDE_MULTIPLIER: float = 1.35

var state: State = State.ENTERING

## 0 = fully sated, 1 = desperate.
var thirst: float = 0.6
var hunger: float = 0.3

## 0 = furious, 1 = delighted.
var mood: float = MOOD_START

var claimed_seat: Seat = null
var active_order: PatronOrder = null

## Copper owed for delivered orders, settled on leaving.
var tab_copper: int = 0

var _entrance_point: Vector3 = Vector3.ZERO
var _exit_point: Vector3 = Vector3.ZERO
var _wait_seconds: float = 0.0
var _consume_seconds_left: float = 0.0
var _linger_seconds_left: float = 0.0
var _drinks_had: int = 0
var _meals_had: int = 0
var _second_round_done: bool = false
var _toast_done: bool = false
var _waiting_line_said: bool = false
var _brawl_seconds_left: float = 0.0
var _brawl_opponent: PatronNPC = null
var _left_angry: bool = false


## Configures spawn/exit routing; must be called before entering the tree.
func setup(patron_race: RaceData, entrance: Vector3, exit_point: Vector3) -> void:
	race = patron_race
	_entrance_point = entrance
	_exit_point = exit_point
	thirst = clampf(randf_range(0.45, 0.75) * maxf(race.thirst_rate, 0.1), 0.0, 0.9)
	hunger = clampf(randf_range(0.2, 0.5) * race.hunger_rate, 0.0, 0.9)
	if not race.given_names.is_empty():
		npc_name = race.given_names[randi() % race.given_names.size()]
	else:
		npc_name = race.display_name


func _ready() -> void:
	super()
	name = "Patron_%s_%s" % [race.id, npc_name]
	navigate_to(_entrance_point)


func _exit_tree() -> void:
	_release_seat()


func move_speed() -> float:
	var base: float = super()
	if _left_angry and state == State.LEAVING:
		return base * ANGRY_STRIDE_MULTIPLIER
	return base


# --- Think loop ---------------------------------------------------------------


func _think(elapsed: float) -> void:
	_accumulate_needs(elapsed)

	# Priority 1: danger.
	if state == State.FIGHTING:
		_think_fighting(elapsed)
		return
	if _maybe_start_brawl():
		return
	# Priority 2/3: needs and service (seated states).
	match state:
		State.FINDING_SEAT:
			_think_finding_seat()
		State.SITTING:
			_think_sitting()
		State.WAITING_ORDER:
			_think_waiting(elapsed)
		State.CONSUMING:
			_think_consuming(elapsed)
		State.SOCIALIZING:
			_think_socializing(elapsed)
		_:
			pass


func _accumulate_needs(elapsed: float) -> void:
	if race == null or elapsed <= 0.0:
		return
	thirst = clampf(thirst + THIRST_PER_SECOND * race.thirst_rate * elapsed, 0.0, 1.0)
	hunger = clampf(hunger + HUNGER_PER_SECOND * race.hunger_rate * elapsed, 0.0, 1.0)


# --- State: entering and seating ------------------------------------------------


func _on_navigation_arrived() -> void:
	match state:
		State.ENTERING:
			EventBus.patron_entered.emit(self)
			say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_GREETING, race.id))
			_set_state(State.FINDING_SEAT)
		State.GOING_TO_SEAT:
			_arrive_at_seat()
		State.LEAVING:
			_despawn()
		_:
			pass


func _think_finding_seat() -> void:
	if claimed_seat != null and is_instance_valid(claimed_seat):
		return
	var seat: Seat = _pick_seat()
	if seat == null:
		# Nowhere to sit: grumble once and leave.
		mood = maxf(0.0, mood - 0.2)
		_begin_leaving(false)
		return
	if not seat.try_claim(self):
		return
	claimed_seat = seat
	claimed_seat.occupancy_changed.connect(_on_seat_occupancy_changed)
	_set_state(State.GOING_TO_SEAT)
	navigate_to(seat.stand_point())


func _pick_seat() -> Seat:
	if race.unique_trait == RaceData.UniqueTrait.ALOOF:
		return SeatRegistry.most_isolated_free_seat(
			self, global_position, NEIGHBOR_RADIUS
		)
	return SeatRegistry.closest_free_seat(self, global_position)


func _arrive_at_seat() -> void:
	if claimed_seat == null or not is_instance_valid(claimed_seat):
		_set_state(State.FINDING_SEAT)
		return
	sit_at(claimed_seat)
	_set_state(State.SITTING)
	EventBus.patron_seated.emit(self, claimed_seat)
	_apply_neighbor_reactions()


# --- State: sitting and ordering --------------------------------------------------


func _think_sitting() -> void:
	# Aloof races leave when the room crowds in around them.
	if race.unique_trait == RaceData.UniqueTrait.ALOOF and _is_too_crowded():
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_LEAVING, race.id))
		_begin_leaving(false)
		return
	var wants_drink: bool = thirst >= NEED_ORDER_THRESHOLD
	var wants_food: bool = (
		hunger >= NEED_ORDER_THRESHOLD
		and race.hunger_rate > 0.0
		and not race.preferred_food_ids.is_empty()
	)
	if wants_drink or wants_food:
		_place_order(wants_drink)
		return
	# Nothing needed: shift to socializing/lingering.
	_linger_seconds_left = (
		SOCIAL_LINGER_BASE_SECONDS
		+ SOCIAL_LINGER_PER_SOCIABILITY * race.sociability
	)
	_set_state(State.SOCIALIZING)


func _place_order(wants_drink: bool) -> void:
	var kind: PatronOrder.Kind = (
		PatronOrder.Kind.DRINK if wants_drink else PatronOrder.Kind.FOOD
	)
	var pool: Array[StringName] = (
		race.preferred_drink_ids if wants_drink else race.preferred_food_ids
	)
	if pool.is_empty():
		# No preference data for this need; treat it as satisfied.
		if wants_drink:
			thirst = NEED_SATISFIED_VALUE
		else:
			hunger = NEED_SATISFIED_VALUE
		return
	var item_id: StringName = pool[0]
	active_order = PatronOrder.new(kind, item_id, self)
	_wait_seconds = 0.0
	_waiting_line_said = false
	say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_ORDERING, race.id))
	_set_state(State.WAITING_ORDER)
	EventBus.order_placed.emit(active_order)


func _think_waiting(elapsed: float) -> void:
	if active_order == null or not active_order.is_active():
		return
	_wait_seconds += elapsed
	mood = maxf(0.0, mood - MOOD_WAIT_PENALTY_PER_SECOND * elapsed)
	var patience: float = race.patience_seconds
	if _wait_seconds > patience:
		# Out of patience: cancel, get angry, leave without paying the tab.
		active_order.status = PatronOrder.Status.CANCELLED
		active_order = null
		mood = 0.0
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_ANGRY, race.id))
		_begin_leaving(true)
	elif _wait_seconds > patience * 0.5 and not _waiting_line_said:
		_waiting_line_said = true
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_WAITING, race.id))


## Called by staff (via order flow) when the order lands on the table.
func receive_order(order: PatronOrder) -> void:
	if order != active_order or state != State.WAITING_ORDER:
		return
	order.status = PatronOrder.Status.DELIVERED
	tab_copper += order.price_copper
	mood = clampf(mood + MOOD_SERVED_BONUS, 0.0, 1.0)
	if race.favors_item(order.item_id):
		mood = clampf(mood + MOOD_FAVORITE_BONUS, 0.0, 1.0)
	if order.kind == PatronOrder.Kind.DRINK:
		thirst = NEED_SATISFIED_VALUE
		_drinks_had += 1
		_consume_seconds_left = CONSUME_SECONDS_DRINK
	else:
		hunger = NEED_SATISFIED_VALUE
		_meals_had += 1
		_consume_seconds_left = CONSUME_SECONDS_FOOD
	say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_SERVED, race.id))
	active_order = null
	_set_state(State.CONSUMING)
	EventBus.order_delivered.emit(order)


func _think_consuming(elapsed: float) -> void:
	_consume_seconds_left -= elapsed
	if _consume_seconds_left > 0.0:
		return
	# Finished the round; race quirks fire here.
	if (
		race.unique_trait == RaceData.UniqueTrait.WAR_TOAST
		and _drinks_had > 0
		and not _toast_done
	):
		_toast_done = true
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_TOAST, race.id))
	if _maybe_order_second_round():
		return
	_linger_seconds_left = (
		SOCIAL_LINGER_BASE_SECONDS
		+ SOCIAL_LINGER_PER_SOCIABILITY * race.sociability
	)
	_set_state(State.SOCIALIZING)


func _maybe_order_second_round() -> bool:
	if _second_round_done:
		return false
	match race.unique_trait:
		RaceData.UniqueTrait.SECOND_ROUND:
			if _drinks_had == 1:
				_second_round_done = true
				say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_SECOND, race.id))
				thirst = 1.0
				_set_state(State.SITTING)
				return true
		RaceData.UniqueTrait.SECOND_LUNCH:
			if _meals_had == 1:
				_second_round_done = true
				say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_SECOND, race.id))
				hunger = 1.0
				_set_state(State.SITTING)
				return true
		_:
			pass
	return false


# --- State: socializing -----------------------------------------------------------


func _think_socializing(elapsed: float) -> void:
	_linger_seconds_left -= elapsed
	# New needs interrupt lingering.
	if thirst >= NEED_ORDER_THRESHOLD or (
		hunger >= NEED_ORDER_THRESHOLD and race.hunger_rate > 0.0
	):
		_set_state(State.SITTING)
		return
	if _linger_seconds_left <= 0.0:
		if mood >= MOOD_HAPPY_THRESHOLD:
			say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_SATISFIED, race.id))
		_begin_leaving(false)
		return
	_maybe_socialize_line()


func _maybe_socialize_line() -> void:
	# Undead unsettle their neighbors instead of chatting.
	if race.unique_trait == RaceData.UniqueTrait.GRAVE_CHILL:
		if randf() < CHILL_CHANCE:
			var neighbors: Array[PatronNPC] = _seated_neighbors()
			if not neighbors.is_empty():
				var victim: PatronNPC = neighbors[randi() % neighbors.size()]
				victim.say(DialogueLibrary.patron_line(
					DialogueLibrary.MOMENT_CHILL, victim.race.id
				))
		return
	if (
		race.unique_trait == RaceData.UniqueTrait.GOSSIP
		and randf() < GOSSIP_CHANCE
	):
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_GOSSIP, race.id))
		# Gossip cheers up nearby allies.
		for neighbor: PatronNPC in _seated_neighbors():
			if race.is_ally_of(neighbor.race.id):
				neighbor.mood = clampf(
					neighbor.mood + MOOD_ALLY_NEARBY_BONUS, 0.0, 1.0
				)


# --- State: fighting -----------------------------------------------------------------


func _maybe_start_brawl() -> bool:
	if state != State.SITTING and state != State.SOCIALIZING:
		return false
	if mood > MOOD_ANGRY_THRESHOLD + 0.1:
		return false
	if race.aggression <= 0.0:
		return false
	if randf() > BRAWL_CHANCE_PER_THINK * race.aggression:
		return false
	for neighbor: PatronNPC in _seated_neighbors():
		if race.is_enemy_of(neighbor.race.id) and neighbor.can_be_drawn_into_brawl():
			_start_brawl_with(neighbor)
			return true
	return false


func can_be_drawn_into_brawl() -> bool:
	return (
		state == State.SITTING
		or state == State.SOCIALIZING
		or state == State.CONSUMING
	)


func _start_brawl_with(target: PatronNPC) -> void:
	_brawl_opponent = target
	_enter_brawl(target)
	target.join_brawl(self)
	EventBus.brawl_started.emit(self, target)


## Called on the target patron when an aggressor picks a fight.
func join_brawl(aggressor: PatronNPC) -> void:
	_brawl_opponent = aggressor
	_enter_brawl(aggressor)


func _enter_brawl(opponent: PatronNPC) -> void:
	stand_up()
	stop_navigation()
	face_point(opponent.global_position)
	_brawl_seconds_left = BRAWL_SECONDS
	say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_CONFLICT, race.id))
	mood = 0.0
	_set_state(State.FIGHTING)


func _think_fighting(elapsed: float) -> void:
	if _brawl_opponent == null or not is_instance_valid(_brawl_opponent):
		_end_brawl(false)
		return
	_brawl_seconds_left -= elapsed
	face_point(_brawl_opponent.global_position)
	if _brawl_seconds_left <= 0.0:
		_end_brawl(true)


## Ends the fight. When [param mutual] is true the opponent is told to stop
## too; both storm out angry.
func _end_brawl(mutual: bool) -> void:
	var opponent: PatronNPC = _brawl_opponent
	_brawl_opponent = null
	if mutual and opponent != null and is_instance_valid(opponent):
		EventBus.brawl_ended.emit(self, opponent)
		opponent.break_up_fight()
	say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_ANGRY, race.id))
	_begin_leaving(true)


## External interrupt (bouncer or opponent left): stop fighting and leave.
func break_up_fight() -> void:
	if state != State.FIGHTING:
		return
	_brawl_opponent = null
	say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_ANGRY, race.id))
	_begin_leaving(true)


# --- State: leaving and payment ------------------------------------------------------


func _begin_leaving(angry: bool) -> void:
	_left_angry = angry
	if is_sitting:
		stand_up()
	_release_seat()
	if active_order != null and active_order.is_active():
		active_order.status = PatronOrder.Status.CANCELLED
		active_order = null
	if not angry:
		_settle_tab()
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_LEAVING, race.id))
	_set_state(State.LEAVING)
	navigate_to(_exit_point)


func _settle_tab() -> void:
	if tab_copper <= 0:
		return
	var total: int = tab_copper
	var tip: int = 0
	if mood >= MOOD_HAPPY_THRESHOLD:
		tip = int(ceil(float(tab_copper) * TIP_BASE_FRACTION * race.tip_multiplier))
	if (
		race.unique_trait == RaceData.UniqueTrait.COIN_SKIM
		and randf() < GOBLIN_SKIM_CHANCE
	):
		total = int(floor(float(total) * GOBLIN_SKIM_FRACTION))
		tip = 0
		say(DialogueLibrary.patron_line(DialogueLibrary.MOMENT_SKIM, race.id))
	var paid: int = total + tip
	tab_copper = 0
	GameManager.add_funds(paid)
	EventBus.patron_paid.emit(self, paid)


func _despawn() -> void:
	EventBus.patron_left.emit(self)
	queue_free()


# --- Shared helpers --------------------------------------------------------------------


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _release_seat() -> void:
	if claimed_seat == null:
		return
	if claimed_seat.occupancy_changed.is_connected(_on_seat_occupancy_changed):
		claimed_seat.occupancy_changed.disconnect(_on_seat_occupancy_changed)
	claimed_seat.release(self)
	claimed_seat = null


func _on_seat_occupancy_changed(_seat: Seat, occupant_now: NPCBase) -> void:
	# Defensive: if the seat somehow changed hands, walk away cleanly.
	if occupant_now != self and state in [
		State.GOING_TO_SEAT, State.SITTING, State.WAITING_ORDER,
		State.CONSUMING, State.SOCIALIZING,
	]:
		if is_sitting:
			stand_up()
		_release_seat()
		_set_state(State.FINDING_SEAT)


func _seated_neighbors() -> Array[PatronNPC]:
	var neighbors: Array[PatronNPC] = []
	if claimed_seat == null or not is_instance_valid(claimed_seat):
		return neighbors
	for seat: Seat in SeatRegistry.occupied_neighbors(
		self, claimed_seat, NEIGHBOR_RADIUS
	):
		var neighbor: PatronNPC = seat.occupant as PatronNPC
		if neighbor != null and neighbor != self:
			neighbors.append(neighbor)
	return neighbors


func _apply_neighbor_reactions() -> void:
	for neighbor: PatronNPC in _seated_neighbors():
		if race.is_enemy_of(neighbor.race.id):
			mood = maxf(0.0, mood - MOOD_ENEMY_NEARBY_PENALTY)
		elif race.is_ally_of(neighbor.race.id):
			mood = clampf(mood + MOOD_ALLY_NEARBY_BONUS, 0.0, 1.0)
		# The new arrival also affects the sitter.
		if neighbor.race.is_enemy_of(race.id):
			neighbor.mood = maxf(0.0, neighbor.mood - MOOD_ENEMY_NEARBY_PENALTY)
		elif neighbor.race.is_ally_of(race.id):
			neighbor.mood = clampf(
				neighbor.mood + MOOD_ALLY_NEARBY_BONUS, 0.0, 1.0
			)


func _is_too_crowded() -> bool:
	return _seated_neighbors().size() > CROWD_TOLERANCE_ALOOF
