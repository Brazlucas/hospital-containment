class_name Projectile
extends Area2D
## A bullet. Flies straight for the weapon's range and damages enemies whose hurtbox it touches.

const UNSHADED: Material = preload("res://resources/materials/unshaded.tres")

var _velocity := Vector2.ZERO
var _damage := 1.0
var _crit := false
var _pierce := 0
var _knockback := 0.0
var _life := 1.0
var _explosion := 0.0
var _color := Color(1.0, 0.85, 0.4)
var _size := 1.0
var _hit: Array[Enemy] = []


func _ready() -> void:
	material = UNSHADED  # bullets glow even in a blackout
	z_index = 5  # always above the y-sorted actors
	area_entered.connect(_on_area_entered)


func launch(origin: Vector2, angle: float, data: WeaponData, damage: float, crit: bool, reach: float) -> void:
	global_position = origin
	rotation = angle
	_velocity = Vector2.from_angle(angle) * data.projectile_speed
	_life = reach / data.projectile_speed + 0.1
	_damage = damage
	_crit = crit
	var stats := RunState.stats
	_pierce = data.pierce + int(stats.get_value("pierce"))  # synergies can add holes through the crowd
	_knockback = data.knockback * stats.mult("knockback_pct")
	_explosion = data.explosion_radius * stats.mult("explosion_pct")
	_color = data.projectile_color
	_size = data.projectile_size


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life -= delta
	if _life <= 0.0:
		if _explosion > 0.0:
			_explode()
		else:
			queue_free()


func _draw() -> void:
	var color := _color if not _crit else Color(1.0, 0.45, 0.3)
	draw_line(Vector2(-7.0 * _size, 0), Vector2.ZERO, Color(color, 0.5), _size)
	draw_circle(Vector2.ZERO, 1.6 * _size, color)


## Area weapons: hurts every living enemy within `_explosion` px of where the shot ends.
func _explode() -> void:
	set_physics_process(false)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if e.hit_position().distance_to(global_position) <= _explosion + e.data.hit_radius:
			e.take_damage(_damage, global_position, _crit, _knockback)
	Burst.play(get_parent(), global_position, _explosion, _color)
	AudioManager.play_sfx("mob_explode", -10.0, 0.1)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent() as Enemy
	if enemy == null or enemy.dead or enemy in _hit:
		return
	if _explosion > 0.0:
		_explode()
		return
	_hit.append(enemy)
	enemy.take_damage(_damage, global_position - _velocity.normalized() * 8.0, _crit, _knockback)
	if _pierce <= 0:
		queue_free()
	else:
		_pierce -= 1
