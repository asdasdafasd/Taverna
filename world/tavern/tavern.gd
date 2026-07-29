class_name Tavern
extends Node3D
## The Wandering Flagon interior: assembles architecture, furniture, props,
## lighting, and atmosphere, and bakes the navigation mesh at runtime so the
## floor layout is ready for patron pathfinding in later phases.

const NAV_AGENT_RADIUS: float = 0.3
const NAV_AGENT_HEIGHT: float = 1.8
const NAV_MAX_CLIMB: float = 0.3
const NAV_MAX_SLOPE_DEGREES: float = 50.0
const NAV_CELL_SIZE: float = 0.2

## Nodes in this group (plus their subtrees) feed the navmesh bake.
const NAV_SOURCE_GROUP: StringName = &"navigation_source"

@onready var _navigation_region: NavigationRegion3D = %NavigationRegion


func _ready() -> void:
	_navigation_region.bake_finished.connect(_on_navigation_baked)
	_configure_navigation.call_deferred()


func _on_navigation_baked() -> void:
	EventBus.navigation_ready.emit()


func _configure_navigation() -> void:
	var navigation_mesh: NavigationMesh = NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = (
		NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	)
	navigation_mesh.geometry_source_geometry_mode = (
		NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	)
	navigation_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	navigation_mesh.geometry_collision_mask = 1
	navigation_mesh.agent_radius = NAV_AGENT_RADIUS
	navigation_mesh.agent_height = NAV_AGENT_HEIGHT
	navigation_mesh.agent_max_climb = NAV_MAX_CLIMB
	navigation_mesh.agent_max_slope = NAV_MAX_SLOPE_DEGREES
	navigation_mesh.cell_size = NAV_CELL_SIZE
	_navigation_region.navigation_mesh = navigation_mesh
	_navigation_region.bake_navigation_mesh(true)
