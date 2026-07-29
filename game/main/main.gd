class_name Main
extends Node3D
## Root of the main game flow: mouse capture, pause, and quick save/load.
##
## Runs with [constant Node.PROCESS_MODE_ALWAYS] so it keeps receiving input
## while the tree is paused; the tavern and player instances are explicitly
## pausable.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.post_notification.call_deferred("Welcome to The Wandering Flagon.")


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
	else:
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


func _maybe_recapture_mouse(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if (
		Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		and GameManager.state == GameManager.State.PLAYING
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
