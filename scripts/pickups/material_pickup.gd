class_name MaterialPickup
extends Node2D
## A dropped material (the old game's coin). Thrown in a small arc, it lands and spins; inside the
## player's pickup range it is pulled in and collected. At the end of a wave vacuum() pulls in all of them.

const BASE_MAGNET := 36.0  ## px at +0% pickup range
const PICKUP_RANGE := 8.0

@export var value := 1

var _landed := false
var _collected := false
var _vacuum := false
var _toss_tween: Tween

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	add_to_group("materials")
	_sprite.play("spin")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("spin")


## Throws the pickup from where it is to `landing` (world coords) in an arc.
func toss(landing: Vector2, height := 14.0) -> void:
	var start := global_position
	_sprite.play("toss")
	_toss_tween = create_tween()
	_toss_tween.tween_method(func(k: float):
		global_position = start.lerp(landing, k)
		_sprite.position.y = -5.0 - sin(k * PI) * height, 0.0, 1.0, randf_range(0.28, 0.42))
	_toss_tween.tween_callback(_land)


func _land() -> void:
	_landed = true
	_sprite.position.y = -5.0
	_sprite.play("land")
	await _sprite.animation_finished
	if not _collected:
		_sprite.play("spin")


## Flies to the player from anywhere, even mid-toss.
func vacuum() -> void:
	_vacuum = true
	if _toss_tween:
		_toss_tween.kill()
	_landed = true
	_sprite.position.y = -5.0


func _process(delta: float) -> void:
	if _collected or not _landed:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.dead:
		return
	var to := player.global_position - global_position
	var d := to.length()
	var magnet := BASE_MAGNET * RunState.stats.mult("pickup_range_pct")
	if d <= PICKUP_RANGE:
		_collect()
	elif _vacuum:
		global_position += to.normalized() * minf(d, 280.0 * delta)
	elif d <= magnet:
		global_position += to.normalized() * minf(d, lerpf(60.0, 210.0, 1.0 - d / magnet) * delta)


func _collect() -> void:
	_collected = true
	RunState.add_materials(value)
	AudioManager.play_sfx("blip", -14.0, 0.1)
	_shadow.visible = false
	_sprite.play("collect")  # sparkle burst, then it disappears
	await _sprite.animation_finished
	queue_free()
