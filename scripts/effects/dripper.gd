class_name Dripper
extends Node2D
## A leak: a drop falls from the ceiling onto this node's position and emits `landed`,
## which the Puddle below turns into ripples. The node is the point where the drop lands.

signal landed

@export var fall_height := 60.0  ## px above the node where the drop starts
@export var fall_time := 0.42
@export var interval_min := 0.9
@export var interval_max := 2.6
@export var drop_color := Color(0.8, 0.95, 1.0, 1.0)
@export var sfx := ""  ## played on landing, quieter the farther the player is (empty = silent, the drip sound was removed)

var _drop_t := -1.0  ## 0..1 while falling
var _wait := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 40  # the drop falls in front of everything
	_wait = randf_range(0.0, interval_max)


func _process(delta: float) -> void:
	if _drop_t >= 0.0:
		_drop_t += delta / fall_time
		if _drop_t >= 1.0:
			_drop_t = -1.0
			_wait = randf_range(interval_min, interval_max)
			_play_sound()
			landed.emit()
	else:
		_wait -= delta
		if _wait <= 0.0:
			_drop_t = 0.0
	queue_redraw()


func _draw() -> void:
	if _drop_t < 0.0:
		return
	var y := -fall_height * (1.0 - _drop_t * _drop_t)  # accelerates
	var a := minf(1.0, _drop_t * 6.0)
	draw_rect(Rect2(Vector2(-0.5, y - 2.0), Vector2(1.0, 3.0)), Color(drop_color, drop_color.a * a))


func _play_sound() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var d := global_position.distance_to(player.global_position) if player else 0.0
	if sfx != "" and d < 320.0:
		AudioManager.play_sfx(sfx, -9.0 - d * 0.04, 0.15)
