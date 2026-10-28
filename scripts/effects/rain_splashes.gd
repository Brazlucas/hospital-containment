class_name RainSplashes
extends Node2D
## Rain hitting the floor: small, flat rings that spread and fade, everywhere around the camera. It lives in the
## world (on the floor, under the actors), listens to Events.weather_changed for how hard it rains, and draws all
## the rings in one go.

const LIFE := 0.5  ## seconds a ring lasts
const MAX_RADIUS := 6.0
const RATE := 110.0  ## new rings per second at full rain
const SQUASH := 0.55  ## the floor is flattened a little, as the camera looks down at an angle
const MAX_RINGS := 220

var _rain := 0.0
var _rings: Array[Vector3] = []  ## x, y = world position, z = age


func _ready() -> void:
	z_as_relative = false
	z_index = -43  # on the floor: above the stains, under the actors
	Events.weather_changed.connect(func(rain: float, _lightning: bool): _rain = rain)


func _process(delta: float) -> void:
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].z += delta
		if _rings[i].z >= LIFE:
			_rings.remove_at(i)
	if _rain > 0.0:
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			var center := camera.get_screen_center_position()
			var half := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
			var count := int(RATE * _rain * delta) + (1 if randf() < fmod(RATE * _rain * delta, 1.0) else 0)
			for i in count:
				if _rings.size() < MAX_RINGS:
					_rings.append(Vector3(center.x + randf_range(-half.x, half.x), center.y + randf_range(-half.y, half.y), 0.0))
	if _rain > 0.0 or not _rings.is_empty():
		queue_redraw()


func _draw() -> void:
	for ring in _rings:
		var k := ring.z / LIFE
		draw_set_transform(Vector2(ring.x, ring.y), 0.0, Vector2(1.0, SQUASH))
		draw_arc(Vector2.ZERO, 1.0 + k * MAX_RADIUS, 0.0, TAU, 14, Color(0.82, 0.92, 1.0, (1.0 - k) * 0.55), 1.0)
		if k < 0.25:  # the tiny splash at the moment of impact
			draw_circle(Vector2.ZERO, 1.2, Color(1, 1, 1, (0.25 - k) * 3.0))
