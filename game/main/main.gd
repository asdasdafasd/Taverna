class_name Main
extends Node3D
## Root of the main game flow: startup loading, mouse capture, the pause
## menu (with settings and save actions), and quick save/load.
##
## Runs with [constant Node.PROCESS_MODE_ALWAYS] so it keeps receiving input
## while the tree is paused; the tavern and player instances are explicitly
## pausable.

## Deferred one frame so all save participants are in the tree before load.
const STARTUP_LOAD_DELAY_FRAMES: int = 2

var _pause_menu: PauseMenu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Resume the world clock (the title screen freezes it).
	TimeManager.clock_paused = false
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	if StartupOptions.load_save_on_start:
		StartupOptions.load_save_on_start = false
		_load_after_startup.call_deferred()
	else:
		_fresh_start.call_deferred()


func _fresh_start() -> void:
	# Reset autoload state in case a previous session ran this launch.
	await get_tree().process_frame
	SaveManager.apply_new_game_state()
	EventBus.post_notification("Welcome to The Wandering Flagon.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("quicksave"):
		_quicksave()
	elif event.is_action_pressed("quickload"):
		_quickload()
	else:
		_maybe_recapture_mouse(event)


func _toggle_pause() -> void:
	if GameManager.is_paused():
		GameManager.resume_game()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif GameManager.state == GameManager.State.PLAYING and not get_tree().paused:
		# The tree can be paused with state PLAYING while a dialogue is
		# open; the dialogue owns Esc handling in that window.
		GameManager.pause_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _quicksave() -> void:
	if SaveManager.save_game():
		EventBus.post_notification("Game saved.")
	else:
		EventBus.post_notification("Saving failed — see the log.")


func _quickload() -> void:
	if not SaveManager.has_save():
		EventBus.post_notification("No save found yet. Press F5 to save.")
		return
	if SaveManager.load_game():
		EventBus.post_notification("Game loaded.")
	else:
		EventBus.post_notification("Loading failed — see the log.")


func _load_after_startup() -> void:
	# Wait until every save participant has entered the tree.
	for _frame: int in STARTUP_LOAD_DELAY_FRAMES:
		await get_tree().process_frame
	if SaveManager.load_game():
		EventBus.post_notification("Welcome back, keeper.")
	else:
		SaveManager.apply_new_game_state()
		EventBus.post_notification("The save could not be read; starting fresh.")


func _maybe_recapture_mouse(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if (
		Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		and GameManager.state == GameManager.State.PLAYING
		and not get_tree().paused
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
