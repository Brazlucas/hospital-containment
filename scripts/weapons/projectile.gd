class_name Projectile
extends Area2D
## A bullet. Flies straight for the weapon's range and damages enemies whose hurtbox it touches.

var _velocity := Vector2.ZERO
var _damage := 1.0
var _crit := false
var _pierce := 0
var _knockback := 0.0
var _life := 1.0
var _hit: Array[Enemy] = []


func _ready() -> void:
	z_index = 5  # always above the y-sorted actors
	area_entered.connect(_on_area_entered)


func launch(origin: Vector2, angle: float, data: WeaponData, damage: float, crit: bool, reach: float) -> void:
	global_position = origin
	rotation = angle
	_velocity = Vector2.from_angle(angle) * data.projectile_speed
	_life = reach / data.projectile_speed + 0.1
	_damage = damage
	_crit = crit
	_pierce = data.pierce
	_knockback = data.knockback


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	var color := Color(1.0, 0.85, 0.4) if not _crit else Color(1.0, 0.45, 0.3)
	draw_line(Vector2(-7, 0), Vector2.ZERO, Color(color, 0.5), 1.0)
	draw_circle(Vector2.ZERO, 1.6, color)


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent() as Enemy
	if enemy == null or enemy.dead or enemy in _hit:
		return
	_hit.append(enemy)
	enemy.take_damage(_damage, global_position - _velocity.normalized() * 8.0, _crit, _knockback)
	if _pierce <= 0:
		queue_free()
	else:
		_pierce -= 1
