class_name Arena
extends Node2D
## One arena run: wave -> skill picks -> shop -> next wave, until the last wave is survived or the player dies.
## The room itself (painted background + collision rects) comes from an ArenaLayout resource; a wave can switch to
## another room (WaveData.arena), and the arena fades to black, rebuilds everything and fades back in.
## Child nodes: Background, Decals, Walls, Entities (y-sorted: player, enemies, pickups, bullets),
## WaveDirector, HUD, UpgradeScreen, ShopScreen.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WAVE_END_PAUSE := 1.2  ## seconds between the last zombie falling and the next screen

@export var character: CharacterData
@export var layout: ArenaLayout
@export var waves: Array[WaveData] = []

var player: Player
var full_view := true  ## test: the camera shows the whole arena (the trainer can switch it)
var bounds := Rect2()  ## camera limits / spawn area, in world px

var _current_layout: ArenaLayout
var _blockers: Array[Rect2] = []  ## layout.blockers in world px
var _reflections: ReflectionMap
var _fade: ColorRect
var _lamps: Array[Lamp] = []
var _wave_index := 0
var _ended := false

@onready var _director: WaveDirector = $WaveDirector
@onready var _upgrades: Node = $UpgradeScreen
@onready var _shop: Node = $ShopScreen
@onready var _entities: Node2D = $Entities
@onready var _ambient: CanvasModulate = $Ambient
@onready var _lights: Node2D = $Lights
@onready var _puddles: Node2D = $Puddles
@onready var _fog: Fog = $Fog
@onready var _dust: CPUParticles2D = $Dust
@onready var _ambience: AmbienceDirector = $Ambience


func _ready() -> void:
	RunState.start_run(character)
	AudioManager.play_music("horror_ambient")
	_build_fade()
	_current_layout = _layout_for(0)
	_load_layout(_current_layout)
	player = PLAYER_SCENE.instantiate()
	_entities.add_child(player)
	player.global_position = _current_layout.player_start * _current_layout.art_scale
	player.setup(character)
	player.set_limits(bounds)
	player.set_full_view(full_view, bounds)
	_ambience.setup(_ambient, _lamps, _fog, player.get_node("Torch"))
	Events.player_died.connect(_on_player_died)
	_director.time_up.connect(_on_wave_time_up)
	_upgrades.finished.connect(_shop.open)
	_shop.finished.connect(_on_shop_done)
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


## The room a wave is fought in: the latest `arena` set at or before it, else the arena's own layout.
func _layout_for(index: int) -> ArenaLayout:
	for i in range(index, -1, -1):
		if waves[i].arena != null:
			return waves[i].arena
	return layout


func _start_wave(index: int) -> void:
	var room := _layout_for(index)
	var changed := room != _current_layout
	if changed:
		_switch_room(room)
	_wave_index = index
	RunState.wave = index + 1
	Events.wave_started.emit(RunState.wave, waves.size())
	if index > 0:  # he left through the door last wave: he fades in at the start point
		player.appear_at(room.player_start * room.art_scale)
	_ambience.apply(waves[index].ambience, index == 0 or changed)
	var preset := waves[index].ambience
	if preset != null and preset.rain > 0.0:  # a wet roof: strong, rippling reflections everywhere
		_reflections.soak(0.4 + 0.3 * preset.rain)
	_director.start(waves[index], self, player, _entities)


## Rebuilds the arena as another room and puts the player at its start.
func _switch_room(room: ArenaLayout) -> void:
	_current_layout = room
	get_tree().call_group("enemies", "banish")
	for group in ["gibs", "shells", "ghost_trails", "damage_numbers", "materials"]:
		get_tree().call_group(group, "queue_free")
	for d in $Decals.get_children():
		d.queue_free()
	_load_layout(room)
	player.global_position = room.player_start * room.art_scale
	player.set_limits(bounds)
	player.set_full_view(full_view, bounds)
	_ambience.setup(_ambient, _lamps, _fog, player.get_node("Torch"))


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


## Every zombie still alive collapses (no loot) and the materials fly to the player.
func _on_wave_time_up() -> void:
	Events.wave_finished.emit(RunState.wave)
	get_tree().call_group("enemies", "banish")
	get_tree().call_group("materials", "vacuum")
	Gore.clear(get_tree(), WAVE_END_PAUSE * 0.8)
	if not player.dead:  # a wave won is a fresh start: full health for the next one
		player.heal(RunState.stats.get_value("max_hp"))
	await get_tree().create_timer(WAVE_END_PAUSE).timeout
	if _ended:
		return
	await _player_exits()
	if _ended:
		return
	if _wave_index + 1 >= waves.size():
		_end_run(true)
	else:
		_upgrades.open()  # then the shop opens (see _ready), then the next wave


## The player walks to the room's exit and vanishes through it; then the picks and the shop open.
func _player_exits() -> void:
	var room := _current_layout
	if player.dead or room.exit_point == Vector2.ZERO:
		return
	await player.walk_out(room.exit_point * room.art_scale, room.exit_into * room.art_scale)
	await get_tree().create_timer(0.25).timeout


func _on_shop_done() -> void:
	var next := _wave_index + 1
	if _layout_for(next) == _current_layout:
		_start_wave(next)
		return
	await _fade_to(1.0, 0.5)  # a different room: fade out, rebuild, fade back in
	_start_wave(next)
	_fade_to(0.0, 0.8)


func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	_end_run(false)


func _end_run(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	_director.stop()
	Events.run_ended.emit(victory)


## Trainer: jumps straight to a wave (index is 0-based).
func debug_goto_wave(index: int) -> void:
	if _ended or index < 0 or index >= waves.size():
		return
	get_tree().call_group("enemies", "banish")
	_start_wave(index)


## Trainer: whole-arena camera on / off.
func debug_toggle_full_view() -> void:
	full_view = not full_view
	player.set_full_view(full_view, bounds)


## Trainer: freezes or resumes the wave's clock and spawns.
func debug_toggle_wave_pause() -> void:
	_director.paused = not _director.paused


func debug_wave_paused() -> bool:
	return _director.paused


## Trainer: ends the current wave, so the skill picks and the shop follow as usual.
func debug_finish_wave() -> void:
	_director.finish_now()


## Puts the painted background in place, turns the layout's rects into solid walls, and builds the
## room's effects: the reflection map, water puddles with their leaks, lamps, fog and dust.
func _load_layout(room: ArenaLayout) -> void:
	for node in [$Walls, _lights, _puddles]:  # whatever the previous room left behind
		for c in node.get_children():
			node.remove_child(c)
			c.queue_free()
	_blockers.clear()
	_lamps.clear()
	if _reflections:
		_reflections.queue_free()
	var s := room.art_scale
	var background: Sprite2D = $Background
	background.texture = room.background
	background.scale = Vector2.ONE * s
	var view := room.view_rect if room.view_rect.has_area() else Rect2(Vector2.ZERO, room.background.get_size())
	bounds = Rect2(view.position * s, view.size * s)
	for r in room.blockers:
		var world := Rect2(r.position * s, r.size * s)
		_blockers.append(world)
		var shape := RectangleShape2D.new()
		shape.size = world.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = world.get_center()
		$Walls.add_child(cs)
	var reflections := ReflectionMap.new()
	_reflections = reflections
	add_child(reflections)
	reflections.build(room.background, s, bounds, _blockers)
	for p in room.puddles:
		var puddle := Puddle.new()
		puddle.radius = p.z * s
		_puddles.add_child(puddle)
		puddle.position = Vector2(p.x, p.y) * s
		reflections.stamp_wet(puddle.position, puddle.radius * 1.1, 1.0)
	reflections.snapshot()  # blood that falls from now on is undone at the end of each wave
	for l in room.lights:
		var lamp := Lamp.new()
		_lights.add_child(lamp)
		lamp.configure(l, s)
		_lamps.append(lamp)
	_fog.position = bounds.get_center()
	_fog.size = bounds.size * 1.6
	_dust.position = bounds.get_center()
	_dust.emission_rect_extents = bounds.size * 0.5
