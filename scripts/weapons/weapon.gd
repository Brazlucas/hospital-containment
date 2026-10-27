class_name Weapon
extends Node2D
## Brotato-style weapon: it hovers next to the player, turns toward the nearest enemy in range and
## fires on its own. Everything numeric comes from WeaponData scaled by the run's Stats.

const PROJECTILE := preload("res://scenes/weapons/projectile.tscn")
const GUN_FX: SpriteFrames = preload("res://resources/items/gun_fx.tres")
const AIM_TOLERANCE := 0.25  ## radians the barrel may be off the target and still fire
const HOLD_DISTANCE := 10.0  ## px between the player's centre and the gun

var data: WeaponData
var slot_angle := 0.0  ## where the weapon rests (radians) while nothing is in range

var _player: Player
var _cooldown := 0.0
var _recoil_tween: Tween

@onready var _sprite: Sprite2D = $Sprite
@onready var _muzzle: Marker2D = $Sprite/Muzzle


func setup(d: WeaponData, player: Player) -> void:
	data = d
	_player = player
	if d.icon:
		_sprite.texture = d.icon
	_sprite.position = Vector2(HOLD_DISTANCE, 0)
	rotation = slot_angle


func attack_range() -> float:
	return data.attack_range * RunState.stats.mult("range_pct")


func cooldown_time() -> float:
	return data.cooldown / maxf(0.2, RunState.stats.mult("attack_speed_pct"))


func _physics_process(delta: float) -> void:
	if data == null or _player.dead:
		return
	_cooldown -= delta
	var target := Targeting.nearest_enemy(get_tree(), global_position, attack_range())
	var want := slot_angle
	if target:
		want = (target.hit_position() - global_position).angle()
	rotation = lerp_angle(rotation, want, minf(1.0, delta * 22.0))
	_sprite.scale.y = -1.0 if absf(wrapf(rotation, -PI, PI)) > PI / 2.0 else 1.0  # never upside down
	if target and _cooldown <= 0.0 and absf(angle_difference(rotation, want)) <= AIM_TOLERANCE:
		_fire(target)
		_cooldown = cooldown_time()


func _fire(target: Enemy) -> void:
	var stats := RunState.stats
	var origin := _muzzle.global_position
	var aim := (target.hit_position() - origin).angle()
	var crit := randf() * 100.0 < stats.get_value("crit_chance")
	var damage := data.damage * stats.mult("damage_pct") * (data.crit_multiplier if crit else 1.0)
	for i in data.projectiles:
		var p: Projectile = PROJECTILE.instantiate()
		_player.get_parent().add_child(p)
		p.launch(origin, aim + deg_to_rad(randf_range(-data.spread_deg, data.spread_deg)), data, damage, crit, attack_range())
	_muzzle_flash(origin, aim)
	AudioManager.play_sfx(data.shot_sfx, -6.0, 0.08)
	_player.shake(0.6, 0.06)
	if _recoil_tween:
		_recoil_tween.kill()
	_sprite.position.x = HOLD_DISTANCE - 3.0
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_sprite, "position:x", HOLD_DISTANCE, 0.1)


## The old game's muzzle flash animation, moved to the barrel tip.
func _muzzle_flash(origin: Vector2, angle: float) -> void:
	var flash := AnimatedSprite2D.new()
	flash.sprite_frames = GUN_FX
	flash.animation = &"flash"
	flash.centered = false
	flash.offset = Vector2(-6, -20)  # the burst's origin sits at the barrel tip
	flash.scale = Vector2(0.7, 0.7)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.z_index = 6
	flash.animation_finished.connect(flash.queue_free)
	_player.get_parent().add_child(flash)
	flash.global_position = origin
	flash.rotation = angle
	flash.play("flash")
