class_name Interactable
extends CollisionObject3D
## Base contract for anything the player can focus and interact with.
##
## Attach subclasses to a physics body ([StaticBody3D], [RigidBody3D], or
## [Area3D]) whose collision layer includes "interactable" so the player's
## [InteractionRay] can hit it. Subclasses override [method interact] and may
## override [method get_prompt_text] for dynamic prompts.

## Emitted when the player's interaction ray starts/stops targeting this node.
signal focus_changed(is_focused: bool)

## Emitted after [method interact] runs.
signal interacted(actor: Node3D)

## Verb shown in the HUD prompt, e.g. "Open", "Pick up", "Stoke".
@export var prompt_verb: String = "Use"

## Object name shown in the HUD prompt, e.g. "Cellar Door".
@export var display_name: String = "Object"

## When false the object ignores focus and interaction attempts.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled and is_focused:
			set_focused(false)

var is_focused: bool = false

var _highlight_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_collect_highlight_meshes(self)


## Full prompt line for the HUD, e.g. "Open — Cellar Door".
func get_prompt_text() -> String:
	return "%s — %s" % [prompt_verb, display_name]


## Called by [InteractionRay] when focus starts or ends.
func set_focused(focused: bool) -> void:
	if is_focused == focused:
		return
	if focused and not enabled:
		return
	is_focused = focused
	_apply_highlight(focused)
	focus_changed.emit(focused)


## Called by [InteractionRay] when the player presses interact while focused.
## Returns true when the interaction was handled.
func try_interact(actor: Node3D) -> bool:
	if not enabled:
		return false
	interact(actor)
	interacted.emit(actor)
	EventBus.interaction_performed.emit(self, actor)
	return true


## Override point: perform the object's action. The base implementation posts
## a notification so every interactable responds visibly even before it gets
## bespoke behavior.
func interact(_actor: Node3D) -> void:
	EventBus.post_notification("%s: %s" % [prompt_verb, display_name])


func _collect_highlight_meshes(node: Node) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and _supports_highlight(mesh_instance):
		_highlight_meshes.append(mesh_instance)
	for child: Node in node.get_children():
		_collect_highlight_meshes(child)


## Shader-driven meshes (flames, embers) keep their own look; the grow-outline
## overlay only suits solid geometry.
static func _supports_highlight(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return false
	return not (mesh_instance.get_active_material(0) is ShaderMaterial)


func _apply_highlight(active: bool) -> void:
	var overlay: Material = InteractionHighlight.overlay_material() if active else null
	for mesh_instance: MeshInstance3D in _highlight_meshes:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = overlay
