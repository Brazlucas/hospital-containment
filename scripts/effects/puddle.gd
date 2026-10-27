class_name Puddle
extends Node2D
## A pool of water on the floor with a leak above it. The blob is drawn in code (a dark, glossy shape with
## a pale rim) and the Dripper's drops make rings spread across it. The arena also marks its area as wet
## in the ReflectionMap, which is what makes reflections turn strong and rippling here.

const RIPPLE_TIME := 1.0
const SQUASH := 0.62  ## floor shapes are flattened a little, as the camera looks down at an angle

@export var radius := 20.0
@export var water_color := Color(0.05, 0.1, 0.14, 0.72)
@export var rim_color := Color(0.55, 0.7, 0.8, 0.45)

var _blob := PackedVector2Array()
var _ripples: Array[float] = []  ## ages 0..1; negative = not started yet
var _origin := Vector2.ZERO  ## where the drop lands, relative to the puddle's centre
var _redraw_once := false


func _ready() -> void:
	z_as_relative = false
	z_index = -46  # on the floor: above the stains, under the reflections and every actor
	var phase := randf() * TAU
	for i in 28:
		var a := TAU * i / 28.0
		var r := radius * (0.82 + 0.18 * sin(a * 3.0 + phase) * cos(a * 2.0 - phase))
		_blob.append(Vector2(cos(a) * r, sin(a) * r * SQUASH))
	var dripper := Dripper.new()
	dripper.position = Vector2(randf_range(-0.25, 0.25) * radius, randf_range(-0.2, 0.2) * radius)
	dripper.landed.connect(_on_drop.bind(dripper))
	add_child(dripper)


func _on_drop(dripper: Dripper) -> void:
	_ripples.append(0.0)
	_ripples.append(-0.2)  # a second, later ring
	_origin = dripper.position


func _process(delta: float) -> void:
	if _ripples.is_empty():
		if _redraw_once:
			_redraw_once = false
			queue_redraw()
		return
	for i in _ripples.size():
		_ripples[i] += delta / RIPPLE_TIME
	_ripples = _ripples.filter(func(age: float) -> bool: return age < 1.0)
	_redraw_once = true
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_blob, water_color)
	var shine := PackedVector2Array()
	for p in _blob:
		shine.append(p * 0.55 + Vector2(-radius * 0.12, -radius * 0.06))
	draw_colored_polygon(shine, Color(0.3, 0.42, 0.5, 0.2))
	var rim := _blob.duplicate()
	rim.append(_blob[0])
	draw_polyline(rim, rim_color, 1.0)
	for age in _ripples:
		if age < 0.0:
			continue
		var r := 2.0 + radius * 0.6 * age
		var ring := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			ring.append(_origin + Vector2(cos(a) * r, sin(a) * r * SQUASH))
		draw_polyline(ring, Color(0.8, 0.95, 1.0, 0.8 * (1.0 - age)), 1.0)
