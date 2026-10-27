class_name SpawnMarker
extends Node2D
## A blinking red X where an enemy is about to appear.

signal finished

var duration := 0.8
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		finished.emit()
		queue_free()


func _draw() -> void:
	var c := Color(0.9, 0.1, 0.15, 0.35 + 0.65 * absf(sin(_t * 14.0)))
	var r := 6.0
	draw_line(Vector2(-r, -r), Vector2(r, r), c, 1.5)
	draw_line(Vector2(-r, r), Vector2(r, -r), c, 1.5)
