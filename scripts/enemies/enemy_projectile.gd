class_name EnemyProjectile
extends Node2D
## Something a zombie throws at the player: a syringe or a glob of bile. It flies in a straight line to where the
## player stood when it was thrown (so moving dodges it), stops at walls and hurts the player on contact.
## It travels on the floor plane and is drawn raised by HEIGHT, like everything else in the 3/4 view.

const UNSHADED: Material = preload("res://resources/materials/unshaded.tres")
const HEIGHT := 16.0  ## px above the floor it is drawn
const HIT_RADIUS := 9.0
const LIFETIME := 3.0
const LIGHT_TEX: Texture2D = preload("res://resources/textures/light_radial.tres")
const GLOW_COLORS := {EnemyData.Throw.SYRINGE: Color(1.0, 0.18, 0.15), EnemyData.Throw.BILE: Color(0.4, 1.0, 0.25)}

static var _additive: CanvasItemMaterial  ## shared: glows add their light to whatever is behind them

var _velocity := Vector2.ZERO
var _damage := 1.0
var _kind := EnemyData.Throw.SYRINGE
var _life := LIFETIME
var _spin := randf() * TAU
var _age := randf() * TAU
var _halos: Array[Sprite2D] = []


static func launch(parent: Node, from: Vector2, to: Vector2, data: EnemyData, damage: float) -> void:
	var p := EnemyProjectile.new()
	p._damage = damage
	p._kind = data.throw_kind
	p._velocity = (to - from).normalized() * data.throw_speed
	p.z_index = 5
	p.material = UNSHADED
	p.scale = Vector2.ONE * 1.15
	parent.add_child(p)
	p.global_position = from


## A soft halo and a small core, both additive and pulsing a little, so the projectile reads in any light.
func _ready() -> void:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var color: Color = GLOW_COLORS[_kind]
	for spec in [[0.2, Color(color, 0.22)], [0.09, Color(color.lightened(0.3), 0.5)]]:
		var halo := Sprite2D.new()
		halo.texture = LIGHT_TEX
		halo.material = _additive
		halo.position = Vector2(0, -HEIGHT)
		halo.scale = Vector2.ONE * spec[0]
		halo.modulate = spec[1]
		halo.z_index = -1
		add_child(halo)
		_halos.append(halo)


func _physics_process(delta: float) -> void:
	_age += delta
	var pulse := 1.0 + 0.12 * sin(_age * 14.0)
	_halos[0].scale = Vector2.ONE * 0.2 * pulse
	_halos[1].scale = Vector2.ONE * 0.09 * (2.0 - pulse)
	var step := _velocity * delta
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)  # layer 1 = walls
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		queue_free()
		return
	global_position += step
	_spin += delta * (16.0 if _kind == EnemyData.Throw.SYRINGE else 6.0)
	_life -= delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.dead and global_position.distance_to(player.global_position) <= HIT_RADIUS:
		player.take_damage(_damage)
		queue_free()
	elif _life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_circle(Vector2.ZERO, 2.5, Color(0, 0, 0, 0.3))  # shadow on the floor
	var up := Vector2(0, -HEIGHT)
	if _kind == EnemyData.Throw.SYRINGE:
		var dir := Vector2.from_angle(_spin)
		draw_line(up - dir * 4.0, up + dir * 3.0, Color(0.88, 0.93, 0.97), 2.0)      # barrel
		draw_line(up + dir * 3.0, up + dir * 6.0, Color(0.6, 0.62, 0.66), 1.0)       # needle
		draw_line(up - dir * 4.0, up - dir * 6.0, Color(0.85, 0.2, 0.2), 2.0)        # plunger
	else:
		draw_circle(up, 3.2, Color(0.35, 0.75, 0.2))
		draw_circle(up + Vector2(-0.8, -0.8), 1.4, Color(0.7, 0.95, 0.45))
		draw_circle(up - _velocity.normalized() * 4.0, 1.8, Color(0.35, 0.75, 0.2, 0.5))  # drip trail
