class_name TavernArchitecture
extends Node3D
## Builds the tavern shell: floors, walls with door/window openings,
## ceiling, beams, columns, cellar stairwell, porch, and exterior ground.
##
## Geometry is generated from the layout constants below so the whole
## building stays consistent and easy to retune. Visual meshes are separate
## [MeshInstance3D] nodes; all collision shapes live on one shared
## [StaticBody3D] on the "world" layer.

# --- Layout (meters). The hall is centered on the origin. ------------------
const WALL_HEIGHT: float = 3.6
const WALL_THICKNESS: float = 0.35
const FLOOR_THICKNESS: float = 0.5
const CEILING_THICKNESS: float = 0.25

const HALL_MIN: Vector2 = Vector2(-7.0, -5.0)
const HALL_MAX: Vector2 = Vector2(7.0, 5.0)
const KITCHEN_MIN: Vector2 = Vector2(-1.0, -9.5)
const KITCHEN_MAX: Vector2 = Vector2(7.0, -5.0)
const STAIR_ROOM_MIN: Vector2 = Vector2(-7.0, -9.5)
const STAIR_ROOM_MAX: Vector2 = Vector2(-4.0, -5.0)
const CELLAR_MIN: Vector2 = Vector2(-7.0, -9.5)
const CELLAR_MAX: Vector2 = Vector2(-1.0, -5.0)
const CELLAR_FLOOR_Y: float = -3.0

# --- Openings ---------------------------------------------------------------
const ENTRANCE_X: float = 0.0
const ENTRANCE_WIDTH: float = 1.1
const ENTRANCE_HEIGHT: float = 2.1
const KITCHEN_ARCH_X: float = 3.0
const KITCHEN_ARCH_WIDTH: float = 1.4
const KITCHEN_ARCH_HEIGHT: float = 2.4
const CELLAR_DOOR_X: float = -5.5
const CELLAR_DOOR_WIDTH: float = 1.1
const CELLAR_DOOR_HEIGHT: float = 2.1
const WINDOW_CENTERS_X: Array[float] = [-4.0, 4.0]
const WINDOW_WIDTH: float = 1.6
const WINDOW_HEIGHT: float = 1.4
const WINDOW_SILL: float = 1.1

# --- Stairs -----------------------------------------------------------------
const STAIR_LANDING_DEPTH: float = 0.6
const STAIR_STEP_RISE: float = 0.2
const STAIR_STEP_RUN: float = 0.24
const STAIR_STEP_COUNT: int = 15

# --- Structure details ------------------------------------------------------
const BEAM_SIZE: float = 0.22
const BEAM_POSITIONS_Z: Array[float] = [-3.0, 0.0, 3.0]
const COLUMN_SIZE: float = 0.3
const COLUMN_POSITIONS_X: Array[float] = [-2.5, 2.5]

# --- Porch and exterior -----------------------------------------------------
const PORCH_HALF_WIDTH: float = 1.5
const PORCH_DEPTH: float = 2.4
const PORCH_RAIL_HEIGHT: float = 1.0
const PORCH_EXIT_GAP: float = 1.2
const PORCH_STEP_HEIGHT: float = 0.2
const GROUND_Y_TOP: float = -0.4
const GROUND_EXTENT: float = 25.0

var _material_wood_floor: Material = preload("res://assets/materials/wood_floor.tres")
var _material_wood_dark: Material = preload("res://assets/materials/wood_dark.tres")
var _material_wood_mid: Material = preload("res://assets/materials/wood_mid.tres")
var _material_stone_wall: Material = preload("res://assets/materials/stone_wall.tres")
var _material_stone_dark: Material = preload("res://assets/materials/stone_dark.tres")
var _material_glass: Material = preload("res://assets/materials/window_glass.tres")

var _collision_body: StaticBody3D = null
var _box_counter: int = 0


## One rectangular hole in a wall. [member sill] is 0 for doorways.
class WallOpening:
	var center: float
	var width: float
	var height: float
	var sill: float

	func _init(p_center: float, p_width: float, p_height: float, p_sill: float = 0.0) -> void:
		center = p_center
		width = p_width
		height = p_height
		sill = p_sill

	func bottom() -> float:
		return sill

	func top() -> float:
		return sill + height


func _ready() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "ArchitectureBody"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_build_floors()
	_build_hall_walls()
	_build_kitchen_walls()
	_build_stair_room_walls()
	_build_cellar()
	_build_ceilings()
	_build_beams_and_columns()
	_build_porch()
	_build_exterior_ground()


# --- Floors ------------------------------------------------------------------


func _build_floors() -> void:
	_add_slab("HallFloor", HALL_MIN, HALL_MAX, -FLOOR_THICKNESS, 0.0, _material_wood_floor)
	_add_slab(
		"KitchenFloor", KITCHEN_MIN, KITCHEN_MAX, -FLOOR_THICKNESS, 0.0, _material_stone_dark
	)
	_add_slab(
		"CellarFloor",
		CELLAR_MIN,
		CELLAR_MAX,
		CELLAR_FLOOR_Y - FLOOR_THICKNESS,
		CELLAR_FLOOR_Y,
		_material_stone_dark
	)


# --- Walls -------------------------------------------------------------------


func _build_hall_walls() -> void:
	var south_openings: Array[WallOpening] = [
		WallOpening.new(ENTRANCE_X, ENTRANCE_WIDTH, ENTRANCE_HEIGHT),
	]
	for window_x: float in WINDOW_CENTERS_X:
		south_openings.append(
			WallOpening.new(window_x, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_SILL)
		)
	_add_wall_x("HallSouth", HALL_MIN.x, HALL_MAX.x, HALL_MAX.y, south_openings)
	for window_x: float in WINDOW_CENTERS_X:
		_add_window_glass("HallWindow", Vector3(window_x, 0.0, HALL_MAX.y))

	var north_openings: Array[WallOpening] = [
		WallOpening.new(CELLAR_DOOR_X, CELLAR_DOOR_WIDTH, CELLAR_DOOR_HEIGHT),
		WallOpening.new(KITCHEN_ARCH_X, KITCHEN_ARCH_WIDTH, KITCHEN_ARCH_HEIGHT),
	]
	_add_wall_x("HallNorth", HALL_MIN.x, HALL_MAX.x, HALL_MIN.y, north_openings)

	_add_wall_z("HallWest", HALL_MIN.y, HALL_MAX.y, HALL_MIN.x, [])
	_add_wall_z("HallEast", HALL_MIN.y, HALL_MAX.y, HALL_MAX.x, [])


func _build_kitchen_walls() -> void:
	_add_wall_x("KitchenNorth", KITCHEN_MIN.x, KITCHEN_MAX.x, KITCHEN_MIN.y, [])
	_add_wall_z("KitchenWest", KITCHEN_MIN.y, KITCHEN_MAX.y, KITCHEN_MIN.x, [])
	_add_wall_z("KitchenEast", KITCHEN_MIN.y, KITCHEN_MAX.y, KITCHEN_MAX.x, [])


func _build_stair_room_walls() -> void:
	_add_wall_x("StairNorth", STAIR_ROOM_MIN.x, STAIR_ROOM_MAX.x, STAIR_ROOM_MIN.y, [])
	_add_wall_z("StairWest", STAIR_ROOM_MIN.y, STAIR_ROOM_MAX.y, STAIR_ROOM_MIN.x, [])
	_add_wall_z("StairEast", STAIR_ROOM_MIN.y, STAIR_ROOM_MAX.y, STAIR_ROOM_MAX.x, [])


# --- Cellar ------------------------------------------------------------------


func _build_cellar() -> void:
	# Below-ground perimeter walls from the cellar floor up to ground level.
	_add_box(
		"CellarWallSouth",
		Vector3(CELLAR_MAX.x - CELLAR_MIN.x, -CELLAR_FLOOR_Y, WALL_THICKNESS),
		Vector3(
			(CELLAR_MIN.x + CELLAR_MAX.x) * 0.5,
			CELLAR_FLOOR_Y * 0.5,
			CELLAR_MAX.y + WALL_THICKNESS * 0.5
		),
		_material_stone_dark
	)
	_add_box(
		"CellarWallNorth",
		Vector3(CELLAR_MAX.x - CELLAR_MIN.x, -CELLAR_FLOOR_Y, WALL_THICKNESS),
		Vector3(
			(CELLAR_MIN.x + CELLAR_MAX.x) * 0.5,
			CELLAR_FLOOR_Y * 0.5,
			CELLAR_MIN.y - WALL_THICKNESS * 0.5
		),
		_material_stone_dark
	)
	_add_box(
		"CellarWallWest",
		Vector3(WALL_THICKNESS, -CELLAR_FLOOR_Y, CELLAR_MAX.y - CELLAR_MIN.y),
		Vector3(
			CELLAR_MIN.x - WALL_THICKNESS * 0.5,
			CELLAR_FLOOR_Y * 0.5,
			(CELLAR_MIN.y + CELLAR_MAX.y) * 0.5
		),
		_material_stone_dark
	)
	_add_box(
		"CellarWallEast",
		Vector3(WALL_THICKNESS, -CELLAR_FLOOR_Y, CELLAR_MAX.y - CELLAR_MIN.y),
		Vector3(
			CELLAR_MAX.x + WALL_THICKNESS * 0.5,
			CELLAR_FLOOR_Y * 0.5,
			(CELLAR_MIN.y + CELLAR_MAX.y) * 0.5
		),
		_material_stone_dark
	)
	# Ceiling slab over the cellar's eastern half, flush with ground level
	# (the west half opens into the stairwell above).
	_add_slab(
		"CellarCeiling",
		Vector2(STAIR_ROOM_MAX.x, CELLAR_MIN.y),
		Vector2(CELLAR_MAX.x, CELLAR_MAX.y),
		-CEILING_THICKNESS,
		0.0,
		_material_stone_dark
	)
	# Closes the ground-level gap between the stair room and the kitchen.
	_add_wall_x("CellarBackNorth", STAIR_ROOM_MAX.x, KITCHEN_MIN.x, CELLAR_MIN.y, [])
	_build_cellar_stairs()


func _build_cellar_stairs() -> void:
	var stair_center_x: float = (STAIR_ROOM_MIN.x + STAIR_ROOM_MAX.x) * 0.5
	var stair_width: float = STAIR_ROOM_MAX.x - STAIR_ROOM_MIN.x - 0.2
	var landing_start_z: float = STAIR_ROOM_MAX.y
	var steps_start_z: float = landing_start_z - STAIR_LANDING_DEPTH
	# Top landing at ground level, just inside the cellar door.
	_add_box(
		"StairLanding",
		Vector3(stair_width, FLOOR_THICKNESS, STAIR_LANDING_DEPTH),
		Vector3(
			stair_center_x,
			-FLOOR_THICKNESS * 0.5,
			landing_start_z - STAIR_LANDING_DEPTH * 0.5
		),
		_material_stone_dark
	)
	# Visual steps: thin boxes descending northward. Collision comes from an
	# invisible ramp because CharacterBody3D has no automatic stair stepping.
	for step_index: int in STAIR_STEP_COUNT - 1:
		var top_y: float = -STAIR_STEP_RISE * float(step_index + 1)
		var near_z: float = steps_start_z - STAIR_STEP_RUN * float(step_index)
		var height: float = top_y - CELLAR_FLOOR_Y
		_add_box(
			"StairStep%d" % step_index,
			Vector3(stair_width, height, STAIR_STEP_RUN),
			Vector3(
				stair_center_x,
				CELLAR_FLOOR_Y + height * 0.5,
				near_z - STAIR_STEP_RUN * 0.5
			),
			_material_stone_dark,
			false
		)
	var run_total: float = STAIR_STEP_RUN * float(STAIR_STEP_COUNT)
	_add_collision_ramp(
		"StairRamp",
		stair_width,
		Vector3(stair_center_x, 0.0, steps_start_z),
		Vector3(stair_center_x, CELLAR_FLOOR_Y, steps_start_z - run_total)
	)


# --- Ceiling, beams, columns -------------------------------------------------


func _build_ceilings() -> void:
	_add_slab(
		"MainCeiling",
		Vector2(HALL_MIN.x, KITCHEN_MIN.y),
		Vector2(HALL_MAX.x, HALL_MAX.y),
		WALL_HEIGHT,
		WALL_HEIGHT + CEILING_THICKNESS,
		_material_wood_dark
	)


func _build_beams_and_columns() -> void:
	var hall_width: float = HALL_MAX.x - HALL_MIN.x
	for beam_z: float in BEAM_POSITIONS_Z:
		_add_box(
			"Beam",
			Vector3(hall_width, BEAM_SIZE, BEAM_SIZE),
			Vector3(0.0, WALL_HEIGHT - BEAM_SIZE * 0.5, beam_z),
			_material_wood_dark,
			false
		)
	for column_x: float in COLUMN_POSITIONS_X:
		_add_box(
			"Column",
			Vector3(COLUMN_SIZE, WALL_HEIGHT, COLUMN_SIZE),
			Vector3(column_x, WALL_HEIGHT * 0.5, 0.0),
			_material_wood_dark
		)


# --- Porch and exterior --------------------------------------------------------


func _build_porch() -> void:
	# The deck starts exactly at the hall floor's edge so the doorway strip
	# under the entrance opening is fully covered.
	var porch_near_z: float = HALL_MAX.y
	var porch_far_z: float = porch_near_z + PORCH_DEPTH
	var porch_center_z: float = (porch_near_z + porch_far_z) * 0.5
	_add_box(
		"PorchDeck",
		Vector3(PORCH_HALF_WIDTH * 2.0, FLOOR_THICKNESS, PORCH_DEPTH),
		Vector3(ENTRANCE_X, -FLOOR_THICKNESS * 0.5, porch_center_z),
		_material_wood_dark
	)
	var rail_size_side: Vector3 = Vector3(0.12, PORCH_RAIL_HEIGHT, PORCH_DEPTH)
	for side_sign: float in [-1.0, 1.0]:
		_add_box(
			"PorchRailSide",
			rail_size_side,
			Vector3(
				ENTRANCE_X + side_sign * (PORCH_HALF_WIDTH - 0.06),
				PORCH_RAIL_HEIGHT * 0.5,
				porch_center_z
			),
			_material_wood_mid
		)
	# Front rail is split around a center exit gap that leads to a step.
	var rail_segment_width: float = PORCH_HALF_WIDTH - PORCH_EXIT_GAP * 0.5
	for side_sign: float in [-1.0, 1.0]:
		_add_box(
			"PorchRailFront",
			Vector3(rail_segment_width, PORCH_RAIL_HEIGHT, 0.12),
			Vector3(
				ENTRANCE_X + side_sign * (PORCH_EXIT_GAP * 0.5 + rail_segment_width * 0.5),
				PORCH_RAIL_HEIGHT * 0.5,
				porch_far_z - 0.06
			),
			_material_wood_mid
		)
	# Step down from the deck to the yard through the exit gap.
	_add_box(
		"PorchStep",
		Vector3(PORCH_EXIT_GAP, PORCH_STEP_HEIGHT, 0.5),
		Vector3(
			ENTRANCE_X,
			GROUND_Y_TOP + PORCH_STEP_HEIGHT * 0.5,
			porch_far_z + 0.25
		),
		_material_wood_mid
	)
	# Invisible ramp over the step so the player can walk back up
	# (CharacterBody3D does not climb ledges on its own).
	_add_collision_ramp(
		"PorchRamp",
		PORCH_EXIT_GAP,
		Vector3(ENTRANCE_X, 0.0, porch_far_z - 0.3),
		Vector3(ENTRANCE_X, GROUND_Y_TOP, porch_far_z + 0.7)
	)


func _build_exterior_ground() -> void:
	# Ground slabs meet the walls' outer faces exactly so there are no gaps
	# to fall through along the building perimeter.
	var half_wall: float = WALL_THICKNESS * 0.5
	var building_min: Vector2 = Vector2(HALL_MIN.x - half_wall, KITCHEN_MIN.y - half_wall)
	var building_max: Vector2 = Vector2(HALL_MAX.x + half_wall, HALL_MAX.y + half_wall)
	var ground_bottom: float = GROUND_Y_TOP - FLOOR_THICKNESS
	_add_slab(
		"GroundNorth",
		Vector2(-GROUND_EXTENT, -GROUND_EXTENT),
		Vector2(GROUND_EXTENT, building_min.y),
		ground_bottom,
		GROUND_Y_TOP,
		_material_stone_dark
	)
	_add_slab(
		"GroundSouth",
		Vector2(-GROUND_EXTENT, building_max.y),
		Vector2(GROUND_EXTENT, GROUND_EXTENT),
		ground_bottom,
		GROUND_Y_TOP,
		_material_stone_dark
	)
	_add_slab(
		"GroundWest",
		Vector2(-GROUND_EXTENT, building_min.y),
		Vector2(building_min.x, building_max.y),
		ground_bottom,
		GROUND_Y_TOP,
		_material_stone_dark
	)
	_add_slab(
		"GroundEast",
		Vector2(building_max.x, building_min.y),
		Vector2(GROUND_EXTENT, building_max.y),
		ground_bottom,
		GROUND_Y_TOP,
		_material_stone_dark
	)


# --- Wall assembly helpers -----------------------------------------------------


## Wall running along the X axis at depth [param z], from [param x0] to
## [param x1], with rectangular [param openings] cut out of it.
func _add_wall_x(
	base_name: String, x0: float, x1: float, z: float, openings: Array[WallOpening]
) -> void:
	var sorted: Array[WallOpening] = openings.duplicate()
	sorted.sort_custom(
		func(a: WallOpening, b: WallOpening) -> bool: return a.center < b.center
	)
	var cursor: float = x0
	for opening: WallOpening in sorted:
		var open_start: float = opening.center - opening.width * 0.5
		var open_end: float = opening.center + opening.width * 0.5
		if open_start > cursor:
			_add_wall_segment_x(base_name, cursor, open_start, z, 0.0, WALL_HEIGHT)
		# Header above the opening.
		_add_wall_segment_x(base_name, open_start, open_end, z, opening.top(), WALL_HEIGHT)
		# Sill block below a window opening.
		if opening.bottom() > 0.0:
			_add_wall_segment_x(base_name, open_start, open_end, z, 0.0, opening.bottom())
		cursor = open_end
	if cursor < x1:
		_add_wall_segment_x(base_name, cursor, x1, z, 0.0, WALL_HEIGHT)


## Wall running along the Z axis at [param x], from [param z0] to [param z1].
func _add_wall_z(
	base_name: String, z0: float, z1: float, x: float, openings: Array[WallOpening]
) -> void:
	var sorted: Array[WallOpening] = openings.duplicate()
	sorted.sort_custom(
		func(a: WallOpening, b: WallOpening) -> bool: return a.center < b.center
	)
	var cursor: float = z0
	for opening: WallOpening in sorted:
		var open_start: float = opening.center - opening.width * 0.5
		var open_end: float = opening.center + opening.width * 0.5
		if open_start > cursor:
			_add_wall_segment_z(base_name, cursor, open_start, x, 0.0, WALL_HEIGHT)
		_add_wall_segment_z(base_name, open_start, open_end, x, opening.top(), WALL_HEIGHT)
		if opening.bottom() > 0.0:
			_add_wall_segment_z(base_name, open_start, open_end, x, 0.0, opening.bottom())
		cursor = open_end
	if cursor < z1:
		_add_wall_segment_z(base_name, cursor, z1, x, 0.0, WALL_HEIGHT)


func _add_wall_segment_x(
	base_name: String, x0: float, x1: float, z: float, y0: float, y1: float
) -> void:
	if x1 - x0 < 0.01 or y1 - y0 < 0.01:
		return
	_add_box(
		base_name + "Segment",
		Vector3(x1 - x0, y1 - y0, WALL_THICKNESS),
		Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z),
		_material_stone_wall
	)


func _add_wall_segment_z(
	base_name: String, z0: float, z1: float, x: float, y0: float, y1: float
) -> void:
	if z1 - z0 < 0.01 or y1 - y0 < 0.01:
		return
	_add_box(
		base_name + "Segment",
		Vector3(WALL_THICKNESS, y1 - y0, z1 - z0),
		Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
		_material_stone_wall
	)


func _add_window_glass(base_name: String, wall_position: Vector3) -> void:
	_add_box(
		base_name + "Glass",
		Vector3(WINDOW_WIDTH, WINDOW_HEIGHT, 0.06),
		Vector3(
			wall_position.x,
			WINDOW_SILL + WINDOW_HEIGHT * 0.5,
			wall_position.z
		),
		_material_glass
	)


# --- Primitive helpers -----------------------------------------------------------


## Horizontal slab spanning [param area_min]..[param area_max] on the XZ
## plane, from height [param y0] up to [param y1].
func _add_slab(
	slab_name: String,
	area_min: Vector2,
	area_max: Vector2,
	y0: float,
	y1: float,
	material: Material
) -> void:
	_add_box(
		slab_name,
		Vector3(area_max.x - area_min.x, y1 - y0, area_max.y - area_min.y),
		Vector3(
			(area_min.x + area_max.x) * 0.5,
			(y0 + y1) * 0.5,
			(area_min.y + area_max.y) * 0.5
		),
		material
	)


func _add_box(
	box_name: String,
	size: Vector3,
	center: Vector3,
	material: Material,
	with_collision: bool = true
) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	_box_counter += 1
	var unique_box_name: String = "%s%d" % [box_name, _box_counter]
	mesh_instance.name = unique_box_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = center
	add_child(mesh_instance)
	if not with_collision:
		return
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = unique_box_name + "Shape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.position = center
	_collision_body.add_child(collision_shape)


## Invisible walk ramp between a [param top] edge and a [param bottom] edge
## (both at floor level on the walking surface). Used for stairs and steps
## because CharacterBody3D does not step up ledges automatically.
func _add_collision_ramp(
	ramp_name: String, width: float, top: Vector3, bottom: Vector3
) -> void:
	var run: Vector3 = bottom - top
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	_box_counter += 1
	collision_shape.name = "%s%d" % [ramp_name, _box_counter]
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(width, 0.2, run.length())
	collision_shape.shape = box_shape
	# Orient the box's -Z axis down the slope; its +Y then matches the
	# slope's surface normal. Offset half the thickness below the surface.
	var ramp_basis: Basis = Basis.looking_at(run.normalized(), Vector3.UP)
	collision_shape.basis = ramp_basis
	collision_shape.position = (top + bottom) * 0.5 + ramp_basis.y * -0.1
	_collision_body.add_child(collision_shape)
