class_name InteractionHighlight
extends RefCounted
## Shared focus-highlight overlay material for interactables.
##
## Lazily builds a single grow-outline shader material that every
## [Interactable] reuses as a [member GeometryInstance3D.material_overlay].

const OUTLINE_SHADER_PATH: String = "res://shaders/focus_outline.gdshader"

static var _overlay: ShaderMaterial = null


## The shared overlay material instance (created on first use).
static func overlay_material() -> ShaderMaterial:
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = load(OUTLINE_SHADER_PATH)
	return _overlay
