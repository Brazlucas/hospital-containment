class_name Enemy
extends CharacterBody2D
## One zombie. Data-driven (EnemyData): it walks straight at the player and bites when close.
## On death it bursts into gore and drops materials, which are also the player's XP.

const HURT_SHADER := preload("res://scripts/effects/hurt_flash.gdshader")
const PICKUP_SCENE := preload("res://scenes/pickups/material_pickup.tscn")
const ATTACK_TIME := 0.45  ## seconds the bite animation runs
const BLOCKED_TIME := 0.3  ## seconds without progress before a zombie sidesteps
const DETOUR_TIME := 0.9
const DETOUR_ANGLE := 1.25  ## radians (~70 degrees) off the straight line while sidestepping

var data: EnemyData
var health := 1.0
var dead := false

var _player: Player
var _damage_mult := 1.0
var _speed_mult := 1.0  ## each zombie walks a little faster or slower than its type
var _attack_cd := 0.0
var _attack_t := -1.0  ## seconds into the current bite, -1 = not biting
var _bite_landed := false
var _knock := Vector2.ZERO
var _last_hit_from := Vector2.ZERO
var _blocked_t := 0.0  ## seconds spent pushing against something without getting anywhere
var _detour_t := 0.0  ## seconds left of sidestepping an obstacle
var _detour_sign := 1.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurt_shape: CollisionShape2D = $Hurtbox/Shape


## Called right after the enemy is added to the tree.
func setup(d: EnemyData, hp_mult := 1.0, damage_mult := 1.0) -> void:
	data = d
	health = d.max_hp * hp_mult
	_damage_mult = damage_mult
	_speed_mult = randf_range(0.88, 1.2)
	_player = get_tree().get_first_node_in_group("player") as Player
	_sprite.sprite_frames = d.frames
	_sprite.scale = Vector2.ONE * d.sprite_scale
	var mat := ShaderMaterial.new()  # one per enemy: each flashes red on its own
	mat.shader = HURT_SHADER
	_sprite.material = mat
	$Shadow.scale = Vector2(1.0, 0.5) * d.sprite_scale
	var circle := CircleShape2D.new()
	circle.radius = d.hit_radius
	_hurt_shape.shape = circle
	_hurt_shape.position = Vector2(0, -d.hit_height)
	_sprite.play("walk")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("walk")  # no marching in lockstep


## Where bullets aim.
func hit_position() -> Vector2:
	if data == null:
		return global_position
	return global_position + Vector2(0, -data.hit_height)


func _physics_process(delta: float) -> void:
	if dead or data == null:
		return
	_attack_cd -= delta
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	if _player == null or _player.dead:
		velocity = _knock
		move_and_slide()
		return
	var to := _player.global_position - global_position
	if _attack_t >= 0.0:
		_tick_bite(delta)
		velocity = _knock
	else:
		var heading := to.normalized()
		if _detour_t > 0.0:
			_detour_t -= delta
			heading = heading.rotated(_detour_sign * DETOUR_ANGLE)
		var speed := data.speed * _speed_mult
		if to.length() <= data.lunge_range:
			speed *= data.lunge_speed_mult  # close enough to smell the player: it rushes
		velocity = heading * speed + _knock
		if to.length() <= data.contact_range and _attack_cd <= 0.0:
			_begin_bite()
	move_and_slide()
	_check_blocked(delta, to.length())
	if absf(to.x) > 2.0:
		_sprite.flip_h = to.x < 0.0


## Zombies walk straight at the player, so a bed in between can pin one for good. When it barely moves
## while trying to, it sidesteps (random side) for a moment and then goes straight again.
func _check_blocked(delta: float, dist: float) -> void:
	if _attack_t >= 0.0 or _detour_t > 0.0 or dist <= data.contact_range * 2.0:
		_blocked_t = 0.0
		return
	if get_position_delta().length() < data.speed * delta * 0.3:
		_blocked_t += delta
		if _blocked_t >= BLOCKED_TIME:
			_blocked_t = 0.0
			_detour_t = DETOUR_TIME
			_detour_sign = 1.0 if randf() < 0.5 else -1.0
	else:
		_blocked_t = 0.0


func _begin_bite() -> void:
	_attack_t = 0.0
	_bite_landed = false
	if _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")


## The bite lands at `attack_windup`, and only if the player is still close then: stepping away dodges it.
func _tick_bite(delta: float) -> void:
	_attack_t += delta
	if not _bite_landed and _attack_t >= data.attack_windup:
		_bite_landed = true
		if _player.global_position.distance_to(global_position) <= data.contact_range * 1.6:
			_player.take_damage(data.contact_damage * _damage_mult)
	if _attack_t >= ATTACK_TIME:
		_attack_t = -1.0
		_attack_cd = data.attack_cooldown
		_sprite.play("walk")


func take_damage(amount: float, from: Vector2, crit := false, knockback := 0.0) -> void:
	if dead:
		return
	health -= amount
	_last_hit_from = from
	_knock += (global_position - from).normalized() * knockback
	HurtFlash.play(_sprite, get_tree(), 1.0, 0.2)
	Gore.splash(get_parent(), hit_position(), from, 3.0 if not crit else 6.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	$Body.set_deferred("disabled", true)
	_hurt_shape.set_deferred("disabled", true)
	RunState.kills += 1
	Events.enemy_killed.emit(self)
	Gore.death(get_parent(), hit_position(), _last_hit_from)
	_drop_materials()
	AudioManager.play_sfx("zombie_hurt", -8.0, 0.15)
	queue_free()


## The wave ended: the zombie just collapses, with no loot and no kill credit.
func banish() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	Gore.splash(get_parent(), hit_position(), global_position + Vector2(0, 8), 2.0)
	queue_free()


func _drop_materials() -> void:
	for i in data.materials:
		var p: MaterialPickup = PICKUP_SCENE.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(0, -8)
		p.toss(global_position + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 26.0))
