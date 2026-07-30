extends Node
## Central audio service: buses, ambient bed, day/night music crossfades,
## and event-driven one-shot cues.
##
## Creates Music/Ambient/Sfx buses at runtime, drives their volumes from
## [code]SettingsManager[/code], and subscribes to gameplay signals so the
## rest of the codebase never touches audio directly. All assets are
## procedurally generated WAVs (see [code]tools/generate_audio.py[/code]).
## Autoload name: [code]AudioManager[/code].

const BUS_MUSIC: StringName = &"Music"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_SFX: StringName = &"Sfx"

const MUSIC_FADE_SECONDS: float = 2.5
const NIGHT_FROM_HOUR: int = 20
const NIGHT_TO_HOUR: int = 6

## Cooldown so rapid identical cues (coin bursts) do not stack harshly.
const CUE_COOLDOWN_SECONDS: float = 0.06

const STREAMS: Dictionary[StringName, String] = {
	&"ui_click": "res://assets/audio/ui_click.wav",
	&"interact": "res://assets/audio/interact_thunk.wav",
	&"door": "res://assets/audio/door_creak.wav",
	&"coin": "res://assets/audio/coin_pay.wav",
	&"quest_complete": "res://assets/audio/quest_complete.wav",
	&"quest_failed": "res://assets/audio/quest_failed.wav",
	&"event": "res://assets/audio/event_ping.wav",
	&"punch": "res://assets/audio/brawl_punch.wav",
	&"tension": "res://assets/audio/tension_sting.wav",
}

const AMBIENT_PATH: String = "res://assets/audio/ambient_tavern_loop.wav"
const MUSIC_DAY_PATH: String = "res://assets/audio/music_day_loop.wav"
const MUSIC_NIGHT_PATH: String = "res://assets/audio/music_night_loop.wav"

var _streams: Dictionary[StringName, AudioStream] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer = null
var _music_day: AudioStreamPlayer = null
var _music_night: AudioStreamPlayer = null
var _music_tween: Tween = null
var _night_active: bool = false
var _last_cue_ms: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	_load_streams()
	_create_players()
	_apply_volumes()
	SettingsManager.settings_changed.connect(_apply_volumes)
	TimeManager.hour_passed.connect(_on_hour_passed)
	_connect_gameplay_cues()
	_start_music(_is_night_hour(TimeManager.hour))


## Plays a named one-shot cue on the Sfx bus.
func play_cue(cue: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(cue)
	if stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_cue_ms.get(cue, -1000) < int(CUE_COOLDOWN_SECONDS * 1000.0):
		return
	_last_cue_ms[cue] = now
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	# All voices busy: steal the first.
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


# --- Setup -------------------------------------------------------------------


func _create_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_AMBIENT, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")


func _load_streams() -> void:
	for cue: StringName in STREAMS:
		var stream: AudioStream = load(STREAMS[cue])
		if stream != null:
			_streams[cue] = stream
		else:
			push_warning("AudioManager: missing stream %s" % STREAMS[cue])


func _create_players() -> void:
	for index: int in 6:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	_ambient_player = _make_loop_player("Ambient", AMBIENT_PATH, BUS_AMBIENT)
	_music_day = _make_loop_player("MusicDay", MUSIC_DAY_PATH, BUS_MUSIC)
	_music_night = _make_loop_player("MusicNight", MUSIC_NIGHT_PATH, BUS_MUSIC)
	_ambient_player.play()


func _make_loop_player(
	node_name: String, path: String, bus: StringName
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus
	var stream: AudioStream = load(path)
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / 2
	player.stream = stream
	add_child(player)
	return player


func _connect_gameplay_cues() -> void:
	EventBus.interaction_performed.connect(_on_interaction_performed)
	EventBus.patron_paid.connect(_on_patron_paid)
	EventBus.brawl_started.connect(_on_brawl_started)
	EventBus.order_delivered.connect(_on_order_delivered)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.quest_failed.connect(_on_quest_failed)
	TavernEventsManager.event_fired.connect(_on_event_fired)
	TensionManager.critical_reached.connect(_on_tension_critical)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)


# --- Volume / settings ----------------------------------------------------------


func _apply_volumes() -> void:
	_set_bus_volume(BUS_MUSIC, SettingsManager.music_volume)
	_set_bus_volume(BUS_AMBIENT, SettingsManager.ambient_volume)
	_set_bus_volume(BUS_SFX, SettingsManager.sfx_volume)
	_set_bus_volume(&"Master", SettingsManager.master_volume)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, linear)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


# --- Music by time of day ----------------------------------------------------------


func _on_hour_passed(_day: int, hour: int) -> void:
	var night: bool = _is_night_hour(hour)
	if night != _night_active:
		_crossfade_music(night)


func _is_night_hour(hour: int) -> bool:
	return hour >= NIGHT_FROM_HOUR or hour < NIGHT_TO_HOUR


func _start_music(night: bool) -> void:
	_night_active = night
	_music_day.volume_db = 0.0 if not night else -60.0
	_music_night.volume_db = 0.0 if night else -60.0
	_music_day.play()
	_music_night.play()


func _crossfade_music(to_night: bool) -> void:
	_night_active = to_night
	if _music_tween != null:
		_music_tween.kill()
	var fade_in: AudioStreamPlayer = _music_night if to_night else _music_day
	var fade_out: AudioStreamPlayer = _music_day if to_night else _music_night
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(fade_in, "volume_db", 0.0, MUSIC_FADE_SECONDS)
	_music_tween.tween_property(fade_out, "volume_db", -60.0, MUSIC_FADE_SECONDS)


# --- Gameplay cue handlers ------------------------------------------------------------


func _on_interaction_performed(interactable: Interactable, _actor: Node3D) -> void:
	if interactable is TavernDoor:
		play_cue(&"door", -6.0)
	else:
		play_cue(&"interact", -8.0)


func _on_patron_paid(_patron: PatronNPC, _copper_amount: int) -> void:
	play_cue(&"coin", -4.0)


func _on_order_delivered(_order: PatronOrder) -> void:
	play_cue(&"interact", -14.0)


func _on_brawl_started(_initiator: PatronNPC, _target: PatronNPC) -> void:
	play_cue(&"punch", -2.0)


func _on_quest_completed(_quest: QuestDefinition) -> void:
	play_cue(&"quest_complete", -4.0)


func _on_quest_failed(_quest: QuestDefinition) -> void:
	play_cue(&"quest_failed", -4.0)


func _on_event_fired(_event_id: StringName, _title: String, _text: String) -> void:
	play_cue(&"event", -8.0)


func _on_tension_critical() -> void:
	play_cue(&"tension", -3.0)


func _on_upgrade_purchased(_upgrade: UpgradeData) -> void:
	play_cue(&"coin", -6.0)
