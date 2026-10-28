class_name Burst
extends Node2D
## An expanding ring and a soft flash for an area blast (grenades, toxic bombs, mines). Additive, so it reads in the dark.

const DURATION := 0.35

static var _additive: CanvasItemMaterial

var _radius := 30.0
var _color := Color.WHITE
var _t := 0.0


static func play(parent: Node, at: Vector2, radius: float, color: Color) -> void:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var b := Burst.new()
	b._radius = radius
	b._color = color
	b.material = _additive
	b.z_index = 25
	parent.add_child(b)
	b.global_position = at


func _process(delta: float) -> void:
	_t += delta / DURATION
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - pow(1.0 - _t, 3.0)  # fast at first, then settles
	var fade := 1.0 - _t
	draw_circle(Vector2.ZERO, _radius * k, Color(_color, 0.3 * fade))
	draw_arc(Vector2.ZERO, _radius * k, 0.0, TAU, 32, Color(_color.lightened(0.4), 0.9 * fade), 2.0)
