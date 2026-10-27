class_name Player
extends CharacterBody2D
## The patient. Moves with WASD / arrows; weapons aim and fire by themselves (see Weapon).
## Art is one side drawn facing right and mirrored with flip_h, like Brotato.

const BASE_SPEED := 85.0
const HIT_INVULNERABLE := 0.5  ## seconds of protection after taking a hit
const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")

var hp := 0.0
var dead := false

var _invulnerable := 0.0
var _last_max_hp := 0.0
var _shake_tween: Tween

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _camera: Camera2D = $Camera
@onready var _weapons: Node2D = $Weapons


## Called by the arena right after the player enters the tree and RunState.start_run() has run.
func setup(c: CharacterData) -> void:
	if c.frames != null:
		_sprite.sprite_frames = c.frames
	_last_max_hp = RunState.stats.get_value("max_hp")
	hp = _last_max_hp
	Events.stats_changed.connect(_on_stats_changed)
	Events.player_hp_changed.emit(hp, _last_max_hp)
	var count := RunState.weapons.size()
	for i in count:
		var w: Weapon = WEAPON_SCENE.instantiate()
		w.slot_angle = TAU * i / count
		_weapons.add_child(w)
		w.setup(RunState.weapons[i], self)


func set_limits(r: Rect2) -> void:
	_camera.limit_left = int(r.position.x)
	_camera.limit_top = int(r.position.y)
	_camera.limit_right = int(r.end.x)
	_camera.limit_bottom = int(r.end.y)
	_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * BASE_SPEED * maxf(0.3, RunState.stats.mult("move_speed_pct"))
	move_and_slide()
	var regen := RunState.stats.get_value("hp_regen")
	if regen > 0.0 and hp < _last_max_hp:
		heal(regen * delta)
	if absf(input.x) > 0.1:
		_sprite.flip_h = input.x < 0.0
	var anim := "walk" if input != Vector2.ZERO else "idle"
	if _sprite.animation != anim:
		_sprite.play(anim)


## Where enemies and bullets treat the player as "being": the torso, not the feet.
func hit_position() -> Vector2:
	return global_position + Vector2(0, -18)


func take_damage(amount: float) -> void:
	if dead or _invulnerable > 0.0:
		return
	hp = maxf(0.0, hp - maxf(1.0, amount * RunState.stats.damage_taken_mult()))
	_invulnerable = HIT_INVULNERABLE
	HurtFlash.play(_sprite, get_tree(), 1.0, 0.3)
	shake(2.5, 0.15)
	Events.player_hp_changed.emit(hp, _last_max_hp)
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(_last_max_hp, hp + amount)
	Events.player_hp_changed.emit(hp, _last_max_hp)


## Screen shake: the camera jitters by up to `px` and settles over `time` seconds.
func shake(px: float, time: float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(k: float): _camera.offset = Vector2.from_angle(randf() * TAU) * px * (1.0 - k), 0.0, 1.0, time)
	_shake_tween.tween_callback(func(): _camera.offset = Vector2.ZERO)


## More max HP from an upgrade also heals that much, so the upgrade is felt at once.
func _on_stats_changed() -> void:
	var new_max := RunState.stats.get_value("max_hp")
	hp = clampf(hp + maxf(0.0, new_max - _last_max_hp), 0.0, new_max)
	_last_max_hp = new_max
	Events.player_hp_changed.emit(hp, _last_max_hp)


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	_sprite.stop()
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "rotation", PI / 2.0 * (-1.0 if _sprite.flip_h else 1.0), 0.35)
	tw.tween_property(_sprite, "modulate:a", 0.6, 0.35)
	Events.player_died.emit()
