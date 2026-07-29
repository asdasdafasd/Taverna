class_name MathUtils
extends RefCounted
## Small math helpers shared across gameplay systems.
##
## All functions are static and frame-rate independent where relevant.


## Frame-rate independent exponential smoothing between [param from] and
## [param to]. [param decay] is the responsiveness (higher = snappier,
## useful range roughly 1-30). Based on the standard exp-decay lerp.
static func exp_decay(from: float, to: float, decay: float, delta: float) -> float:
	return to + (from - to) * exp(-decay * delta)


## Vector3 variant of [method exp_decay].
static func exp_decay_v3(from: Vector3, to: Vector3, decay: float, delta: float) -> Vector3:
	return to + (from - to) * exp(-decay * delta)


## Returns the horizontal (XZ-plane) speed of a velocity vector.
static func flat_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()
