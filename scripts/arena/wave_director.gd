class_name WaveDirector
extends Node
## Runs one wave at a time: counts the clock down and spawns enemies from the wave's pool.
## Each spawn is announced by a red X (SpawnMarker) so nobody appears on top of the player unannounced.

signal time_up

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const TELEGRAPH_TIME := 0.8
const MAX_ALIVE := 120  ## spawns are skipped above this many zombies (performance + fairness)
const MIN_PLAYER_DIST := 110.0
const EDGE_MARGIN := 24.0

var _wave: WaveData
var _bounds: Rect2
var _player: Player
var _holder: Node2D
var _time_left := 0.0
var _spawn_in := 0.0
var _running := false
var _markers := 0  ## telegraphs in flight


func start(wave: WaveData, bounds: Rect2, player: Player, holder: Node2D) -> void:
	_wave = wave
	_bounds = bounds
	_player = player
	_holder = holder
	_time_left = wave.duration
	_spawn_in = 0.5
	_running = true
	Events.wave_time_changed.emit(_time_left)


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	_time_left -= delta
	Events.wave_time_changed.emit(maxf(_time_left, 0.0))
	if _time_left <= 0.0:
		_running = false
		time_up.emit()
		return
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = _wave.spawn_interval
		for i in _wave.group_size:
			_spawn_one()


func _spawn_one() -> void:
	if get_tree().get_nodes_in_group("enemies").size() + _markers >= MAX_ALIVE:
		return
	var data := _pick_enemy()
	if data == null:
		return
	var marker := SpawnMarker.new()
	marker.duration = TELEGRAPH_TIME
	marker.z_index = -20
	_holder.add_child(marker)
	marker.global_position = _spawn_point()
	_markers += 1
	marker.finished.connect(_on_marker_finished.bind(marker, data))


func _on_marker_finished(marker: SpawnMarker, data: EnemyData) -> void:
	_markers -= 1
	if not _running:
		return
	var e: Enemy = ENEMY_SCENE.instantiate()
	_holder.add_child(e)
	e.global_position = marker.global_position
	e.setup(data, _wave.hp_multiplier, _wave.damage_multiplier)


func _pick_enemy() -> EnemyData:
	var total := 0.0
	for d in _wave.enemies:
		total += d.spawn_weight
	var r := randf() * total
	for d in _wave.enemies:
		r -= d.spawn_weight
		if r <= 0.0:
			return d
	return _wave.enemies.back() if not _wave.enemies.is_empty() else null


## A random spot inside the arena, preferably away from the player.
func _spawn_point() -> Vector2:
	var area := _bounds.grow(-EDGE_MARGIN)
	var p := area.position
	for i in 8:
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(_player.global_position) >= MIN_PLAYER_DIST:
			break
	return p
