class_name Arena
extends Node2D
## One arena run: wave -> (level-up picks) -> next wave, until the last wave is survived or the player dies.
## Child nodes: Floor, Decals, Walls, Entities (y-sorted: player, enemies, pickups, bullets),
## WaveDirector, HUD, UpgradeScreen.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WAVE_END_PAUSE := 1.2  ## seconds between the last zombie falling and the next screen

@export var character: CharacterData
@export var waves: Array[WaveData] = []
@export var bounds := Rect2(0, 0, 640, 360)

var player: Player

var _wave_index := 0
var _ended := false

@onready var _director: WaveDirector = $WaveDirector
@onready var _upgrades: Node = $UpgradeScreen
@onready var _entities: Node2D = $Entities


func _ready() -> void:
	RunState.start_run(character)
	_build_walls()
	player = PLAYER_SCENE.instantiate()
	_entities.add_child(player)
	player.global_position = bounds.get_center()
	player.setup(character)
	player.set_limits(bounds)
	Events.player_died.connect(_on_player_died)
	_director.time_up.connect(_on_wave_time_up)
	_upgrades.finished.connect(_on_upgrades_done)
	_start_wave(0)


func _unhandled_input(event: InputEvent) -> void:
	if _ended and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _start_wave(index: int) -> void:
	_wave_index = index
	RunState.wave = index + 1
	Events.wave_started.emit(RunState.wave, waves.size())
	_director.start(waves[index], bounds, player, _entities)


## Every zombie still alive collapses (no loot) and the materials fly to the player.
func _on_wave_time_up() -> void:
	Events.wave_finished.emit(RunState.wave)
	get_tree().call_group("enemies", "banish")
	get_tree().call_group("materials", "vacuum")
	await get_tree().create_timer(WAVE_END_PAUSE).timeout
	if _ended:
		return
	if _wave_index + 1 >= waves.size():
		_end_run(true)
	else:
		_upgrades.open()  # one offer per level gained; emits `finished` right away if there is none


func _on_upgrades_done() -> void:
	_start_wave(_wave_index + 1)


func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	_end_run(false)


func _end_run(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	_director.stop()
	Events.run_ended.emit(victory)


## Solid walls just outside `bounds`, so player and enemies share the same limits.
func _build_walls() -> void:
	var t := 32.0
	var rects: Array[Rect2] = [
		Rect2(bounds.position.x - t, bounds.position.y - t, bounds.size.x + 2.0 * t, t),
		Rect2(bounds.position.x - t, bounds.end.y, bounds.size.x + 2.0 * t, t),
		Rect2(bounds.position.x - t, bounds.position.y, t, bounds.size.y),
		Rect2(bounds.end.x, bounds.position.y, t, bounds.size.y),
	]
	for r in rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.get_center()
		$Walls.add_child(cs)
