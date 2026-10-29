class_name Player
extends CharacterBody2D
## The patient. Moves with WASD / arrows; weapons aim and fire by themselves (see Weapon).
## Art is one 3/4 view drawn facing down-right and mirrored with flip_h, like Brotato.

const BASE_SPEED := 85.0
const HIT_INVULNERABLE := 0.5  ## seconds of protection after taking a hit
const OVERVIEW_ZOOM := 0.7  ## the zoomed-out camera: 1 = normal, lower = farther away
const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")

var hp := 0.0
var dead := false

var _invulnerable := 0.0
var _last_max_hp := 0.0
var _shake_tween: Tween
var _limits := Rect2()
var _overview := false  ## test camera on, see set_full_view
var _view_area := Rect2()
var _view_screen := Vector2.ONE
var _cutscene := false  ## the wave-end exit is playing: the player cannot steer
var _prev_pos := Vector2.ZERO
var _sprite_scale := Vector2.ONE

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _camera: Camera2D = $Camera
@onready var _weapons: Node2D = $Weapons


## Called by the arena right after the player enters the tree and RunState.start_run() has run.
func setup(c: CharacterData) -> void:
	if c.frames != null:
		_sprite.sprite_frames = c.frames
	_sprite_scale = _sprite.scale
	_last_max_hp = RunState.stats.get_value("max_hp")
	hp = _last_max_hp
	Events.stats_changed.connect(_on_stats_changed)
	Events.weapon_added.connect(_add_weapon)
	Events.weapon_removed.connect(_remove_last_weapon)
	Events.player_healed.connect(heal)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_hp_changed.emit(hp, _last_max_hp)
	for d in RunState.weapons:
		_add_weapon(d)


## Gives the player one more weapon (bought in the shop) and re-spaces the resting spots of all of them.
func _add_weapon(d: WeaponData) -> void:
	var w: Weapon = WEAPON_SCENE.instantiate()
	_weapons.add_child(w)
	w.setup(d, self)
	var count := _weapons.get_child_count()
	for i in count:
		(_weapons.get_child(i) as Weapon).slot_angle = TAU * i / count


## Some synergies heal a little with every kill.
func _on_enemy_killed(_enemy: Node2D) -> void:
	var amount := RunState.stats.get_value("heal_on_kill")
	if amount > 0.0:
		heal(amount)


func _remove_last_weapon() -> void:
	var count := _weapons.get_child_count()
	if count == 0:
		return
	var last := _weapons.get_child(count - 1)
	_weapons.remove_child(last)
	last.queue_free()
	count -= 1
	for i in count:
		(_weapons.get_child(i) as Weapon).slot_angle = TAU * i / count


func set_limits(r: Rect2) -> void:
	_limits = r
	_camera.limit_left = int(r.position.x)
	_camera.limit_top = int(r.position.y)
	_camera.limit_right = int(r.end.x)
	_camera.limit_bottom = int(r.end.y)
	_camera.reset_smoothing()


## Test camera: zoomed out so much more of the arena is visible. It follows the player but never shows past `area`
## (world px), and on an axis where the whole area fits it just stays centred. Off = follows the player at 1x.
func set_full_view(enabled: bool, area: Rect2) -> void:
	_overview = enabled
	if enabled:
		_view_area = area
		_view_screen = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
		_camera.top_level = true  # positioned by hand in _process
		_camera.position_smoothing_enabled = false
		_camera.limit_left = -10000000
		_camera.limit_top = -10000000
		_camera.limit_right = 10000000
		_camera.limit_bottom = 10000000
		_camera.zoom = Vector2.ONE * OVERVIEW_ZOOM
		_camera.global_position = _overview_target()
	else:
		_camera.top_level = false
		_camera.position = Vector2(0, -18)
		_camera.zoom = Vector2.ONE
		_camera.position_smoothing_enabled = true
		set_limits(_limits)


func _overview_target() -> Vector2:
	var half := _view_screen / OVERVIEW_ZOOM * 0.5
	var focus := global_position + Vector2(0, -18)
	var out := _view_area.get_center()
	if _view_area.size.x > half.x * 2.0:
		out.x = clampf(focus.x, _view_area.position.x + half.x, _view_area.end.x - half.x)
	if _view_area.size.y > half.y * 2.0:
		out.y = clampf(focus.y, _view_area.position.y + half.y, _view_area.end.y - half.y)
	return out


func _process(delta: float) -> void:
	if _overview:
		_camera.global_position = _camera.global_position.lerp(_overview_target(), 1.0 - exp(-8.0 * delta))


func _physics_process(delta: float) -> void:
	if dead:
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if _cutscene:
		_animate_by_movement()
		return
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


## End of a wave: the player walks by himself to `door`, then on through it to `inside`, fading away like a ghost
## and shrinking a little as if going deeper. Nobody can steer meanwhile and nothing collides.
func walk_out(door: Vector2, inside: Vector2) -> void:
	if dead:
		return
	_cutscene = true
	_prev_pos = global_position
	collision_mask = 0
	var walk_time := global_position.distance_to(door) / (BASE_SPEED * 1.15)
	var tw := create_tween()
	tw.tween_property(self, "global_position", door, maxf(walk_time, 0.05))
	tw.tween_property(self, "global_position", inside, 0.8)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(_sprite, "scale", _sprite_scale * 0.85, 0.8)
	tw.parallel().tween_property($Torch, "energy", 0.0, 0.8)
	await tw.finished


## Start of a wave: the player fades in at `pos` with a moment of protection. Undoes walk_out().
func appear_at(pos: Vector2) -> void:
	_cutscene = false
	collision_mask = 1
	global_position = pos
	_sprite.scale = _sprite_scale
	_invulnerable = 1.0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	_camera.reset_smoothing()


## While the exit plays the legs follow the movement: face where it goes, walk when it moves.
func _animate_by_movement() -> void:
	var moved := global_position - _prev_pos
	_prev_pos = global_position
	if absf(moved.x) > 0.05:
		_sprite.flip_h = moved.x < 0.0
	var anim := "walk" if moved.length() > 0.1 else "idle"
	if _sprite.animation != anim:
		_sprite.play(anim)


## Where enemies and bullets treat the player as "being": the torso, not the feet.
func hit_position() -> Vector2:
	return global_position + Vector2(0, -18)


func take_damage(amount: float) -> void:
	if dead or _cutscene or _invulnerable > 0.0 or RunState.god_mode:
		return
	var taken := maxf(1.0, amount * RunState.stats.damage_taken_mult())
	hp = maxf(0.0, hp - taken)
	Events.player_hurt.emit(taken)
	Input.start_joy_vibration(0, clampf(0.3 + taken * 0.1, 0.3, 0.8), clampf(0.2 + taken * 0.2, 0.2, 1.0), 0.25)  # the pad shakes too
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
	$Reflection.set_enabled(false)  # the body tips over; its mirror image would not follow
	_sprite.stop()
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "rotation", PI / 2.0 * (-1.0 if _sprite.flip_h else 1.0), 0.35)
	tw.tween_property(_sprite, "modulate:a", 0.6, 0.35)
	Events.player_died.emit()
