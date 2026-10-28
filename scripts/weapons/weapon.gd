class_name Weapon
extends Node2D
## Brotato-style weapon: it hovers next to the player, turns toward the nearest enemy in range and attacks
## on its own. RANGED weapons shoot; MELEE ones swing and hit everything in front of them.
## Everything numeric comes from WeaponData scaled by the run's Stats.

const PROJECTILE := preload("res://scenes/weapons/projectile.tscn")
const GUN_FX: SpriteFrames = preload("res://resources/items/gun_fx.tres")
const LIGHT_TEX: Texture2D = preload("res://resources/textures/light_radial.tres")
const UNSHADED: Material = preload("res://resources/materials/unshaded.tres")
const AIM_TOLERANCE := 0.25  ## radians the weapon may be off the target and still attack
const HOLD_DISTANCE := 10.0  ## px between the player's centre and the hand
const COCKED := 0.75  ## a melee weapon rests raised behind the shoulder, at this fraction of half its arc
const POINT_BLANK := 14.0  ## px: closer than this, a melee blow hits whatever the angle

var data: WeaponData
var slot_angle := 0.0  ## where the weapon rests (radians) while nothing is in range

var _player: Player
var _cooldown := 0.0
var _aim := 0.0  ## where the weapon points, without the swing
var _swing := 0.0  ## radians added to _aim while a melee blow is under way
var _swing_sign := 1.0  ## mirrors the swing when aiming left, so the bat always comes from behind the shoulder
var _swinging := false
var _recoil_tween: Tween
var _flash_light: PointLight2D
var _flash_tween: Tween

@onready var _hand: Node2D = $Hand
@onready var _art: Sprite2D = $Hand/Art
@onready var _muzzle: Marker2D = $Hand/Muzzle


func setup(d: WeaponData, player: Player) -> void:
	data = d
	_player = player
	_art.texture = d.icon
	_art.scale = Vector2.ONE * d.icon_scale
	_art.rotation = deg_to_rad(d.icon_rotation_deg)
	_art.position = d.icon_offset
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if d.icon_scale < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.position = Vector2(HOLD_DISTANCE, 0)
	_muzzle.position = d.muzzle_offset
	_aim = slot_angle
	_swing = _rest_swing()
	rotation = _aim + _swing
	if d.kind == WeaponData.Kind.RANGED:
		_flash_light = PointLight2D.new()  # one permanent light: creating lights mid-game recompiles shaders (a hitch)
		_flash_light.texture = LIGHT_TEX
		_flash_light.color = Color(1.0, 0.8, 0.45)
		_flash_light.texture_scale = 1.1
		_flash_light.energy = 0.0
		add_child(_flash_light)


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
	_aim = lerp_angle(_aim, want, minf(1.0, delta * 22.0))
	if not _swinging:
		_swing_sign = 1.0 if cos(_aim) >= 0.0 else -1.0  # decided once per blow, so the art never flips mid-swing
	rotation = _aim + _swing * _swing_sign
	_hand.scale.y = _swing_sign  # never upside down
	if target and _cooldown <= 0.0 and not _swinging and absf(angle_difference(_aim, want)) <= AIM_TOLERANCE:
		_cooldown = cooldown_time()
		if data.kind == WeaponData.Kind.MELEE:
			_swing_at()
		else:
			_fire(target)


# --- ranged ---------------------------------------------------------------------------------

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
	if data.firearm:
		_muzzle_flash(origin, aim)
		Shell.eject(_player.get_parent(), _hand.global_position, aim, data)
		_flash_light.global_position = origin
		_flash_light.energy = 1.6
		if _flash_tween:
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(_flash_light, "energy", 0.0, 0.1)
	if data.shot_sfx != "":
		AudioManager.play_sfx(data.shot_sfx, -10.0, 0.08)
	_player.shake(0.6, 0.06)
	if _recoil_tween:
		_recoil_tween.kill()
	_hand.position.x = HOLD_DISTANCE - 3.0
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_hand, "position:x", HOLD_DISTANCE, 0.1)


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
	flash.material = UNSHADED  # the burst stays bright whatever the room's light
	flash.animation_finished.connect(flash.queue_free)
	_player.get_parent().add_child(flash)
	flash.global_position = origin
	flash.rotation = angle
	flash.play("flash")


# --- melee ----------------------------------------------------------------------------------

func _rest_swing() -> float:
	if data.kind != WeaponData.Kind.MELEE:
		return 0.0
	return -deg_to_rad(data.melee_arc_deg) * 0.5 * COCKED


## Wind up behind the shoulder, sweep through the target (the blow lands halfway), follow through, and recover.
func _swing_at() -> void:
	_swinging = true
	var half := deg_to_rad(data.melee_arc_deg) * 0.5
	if data.shot_sfx != "":
		AudioManager.play_sfx(data.shot_sfx, -4.0, 0.1)
	var tw := create_tween()
	tw.tween_property(self, "_swing", -half, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_swing", 0.0, data.swing_time * 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(_melee_hit)
	tw.tween_property(self, "_swing", half, data.swing_time * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_swing", _rest_swing(), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _swinging = false)


## Damages every living enemy inside the arc and reach, all at once.
func _melee_hit() -> void:
	var stats := RunState.stats
	var crit := randf() * 100.0 < stats.get_value("crit_chance")
	var damage := data.damage * stats.mult("damage_pct") * (data.crit_multiplier if crit else 1.0)
	var reach := data.melee_reach * stats.mult("range_pct")
	var half := deg_to_rad(data.melee_arc_deg) * 0.5
	var hits := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var to := e.hit_position() - global_position
		var dist := to.length()
		if dist > reach:
			continue
		if dist > POINT_BLANK and absf(angle_difference(_aim, to.angle())) > half:
			continue
		e.take_damage(damage, global_position, crit, data.knockback * stats.mult("knockback_pct"))
		hits += 1
	_slash_trail(reach, half)
	_wind_streaks(reach, half)
	if hits > 0:
		if data.hit_sfx != "":
			AudioManager.play_sfx(data.hit_sfx, -2.0, 0.1)
		_player.shake(1.2 + minf(hits, 4) * 0.4, 0.1)


## A pale crescent that follows the blow's arc and fades out, so the swing reads even at a glance.
func _slash_trail(reach: float, half: float) -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.1))
	curve.add_point(Vector2(1.0, 1.0))
	var line := Line2D.new()
	line.width = 5.0
	line.width_curve = curve
	line.default_color = Color(1.0, 0.95, 0.8, 0.85)
	line.material = UNSHADED
	line.z_index = 6
	for i in 13:
		var a := _aim - half * _swing_sign + 2.0 * half * _swing_sign * i / 12.0
		line.add_point(global_position + Vector2.from_angle(a) * reach * 0.9)
	_player.get_parent().add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)


## A few thin, faint arcs of air around the blow, each covering part of the swing, that fade out fast.
func _wind_streaks(reach: float, half: float) -> void:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(0.5, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	for radius_k in [0.62, 0.8, 1.02]:
		var from := randf_range(0.0, 0.35)
		var to := randf_range(0.65, 1.0)
		var line := Line2D.new()
		line.width = 1.5
		line.width_curve = taper
		line.default_color = Color(1.0, 1.0, 1.0, 0.3)
		line.material = UNSHADED
		line.z_index = 5
		for i in 9:
			var k := lerpf(from, to, i / 8.0)
			var a := _aim - half * _swing_sign + 2.0 * half * _swing_sign * k
			line.add_point(global_position + Vector2.from_angle(a) * reach * radius_k)
		_player.get_parent().add_child(line)
		var tw := line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.22)
		tw.tween_callback(line.queue_free)

