class_name Arena
extends Node2D
## One arena run: wave -> (level-up picks) -> next wave, until the last wave is survived or the player dies.
## The room itself (painted background + collision rects) comes from an ArenaLayout resource.
## Child nodes: Background, Decals, Walls, Entities (y-sorted: player, enemies, pickups, bullets),
## WaveDirector, HUD, UpgradeScreen.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WAVE_END_PAUSE := 1.2  ## seconds between the last zombie falling and the next screen

@export var character: CharacterData
@export var layout: ArenaLayout
@export var waves: Array[WaveData] = []

var player: Player
var bounds := Rect2()  ## camera limits / spawn area, in world px

var _blockers: Array[Rect2] = []  ## layout.blockers in world px
var _lamps: Array[Lamp] = []
var _wave_index := 0
var _ended := false

@onready var _director: WaveDirector = $WaveDirector
@onready var _upgrades: Node = $UpgradeScreen
@onready var _entities: Node2D = $Entities
@onready var _ambient: CanvasModulate = $Ambient
@onready var _lights: Node2D = $Lights
@onready var _puddles: Node2D = $Puddles
@onready var _fog: Fog = $Fog
@onready var _dust: CPUParticles2D = $Dust
@onready var _ambience: AmbienceDirector = $Ambience


func _ready() -> void:
	RunState.start_run(character)
	_load_layout()
	player = PLAYER_SCENE.instantiate()
	_entities.add_child(player)
	player.global_position = layout.player_start * layout.art_scale
	player.setup(character)
	player.set_limits(bounds)
	_ambience.setup(_ambient, _lamps, _fog, player.get_node("Torch"))
	Events.player_died.connect(_on_player_died)
	_director.time_up.connect(_on_wave_time_up)
	_upgrades.finished.connect(_on_upgrades_done)
	_start_wave(0)


func _unhandled_input(event: InputEvent) -> void:
	if _ended and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


## True when `p` (world px) is inside the playable area and at least `margin` px away from every blocker.
func is_free(p: Vector2, margin := 0.0) -> bool:
	if not bounds.has_point(p):
		return false
	for r in _blockers:
		if r.grow(margin).has_point(p):
			return false
	return true


func _start_wave(index: int) -> void:
	_wave_index = index
	RunState.wave = index + 1
	Events.wave_started.emit(RunState.wave, waves.size())
	_ambience.apply(waves[index].ambience, index == 0)
	_director.start(waves[index], self, player, _entities)


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


## Puts the painted background in place, turns the layout's rects into solid walls, and builds the
## room's effects: the reflection map, water puddles with their leaks, lamps, fog and dust.
func _load_layout() -> void:
	var s := layout.art_scale
	var background: Sprite2D = $Background
	background.texture = layout.background
	background.scale = Vector2.ONE * s
	var view := layout.view_rect if layout.view_rect.has_area() else Rect2(Vector2.ZERO, layout.background.get_size())
	bounds = Rect2(view.position * s, view.size * s)
	for r in layout.blockers:
		var world := Rect2(r.position * s, r.size * s)
		_blockers.append(world)
		var shape := RectangleShape2D.new()
		shape.size = world.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = world.get_center()
		$Walls.add_child(cs)
	var reflections := ReflectionMap.new()
	add_child(reflections)
	reflections.build(layout.background, s, bounds, _blockers)
	for p in layout.puddles:
		var puddle := Puddle.new()
		puddle.radius = p.z * s
		_puddles.add_child(puddle)
		puddle.position = Vector2(p.x, p.y) * s
		reflections.stamp_wet(puddle.position, puddle.radius * 1.1, 1.0)
	for l in layout.lights:
		var lamp := Lamp.new()
		_lights.add_child(lamp)
		lamp.configure(l, s)
		_lamps.append(lamp)
	_fog.position = bounds.get_center()
	_fog.size = bounds.size * 1.6
	_dust.position = bounds.get_center()
	_dust.emission_rect_extents = bounds.size * 0.5
