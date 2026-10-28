extends CanvasLayer
## Test trainer, F1 toggles it. Coins, healing, god mode, any weapon, every stat, wave jumps, spawning and game speed.
## It only exists in debug builds (editor runs and debug exports) and does not pause the game, so changes show at once.

const WEAPONS_DIR := "res://resources/data/weapons"
const ENEMIES_DIR := "res://resources/data/enemies"
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const WIDTH := 214.0
const STAT_STEPS := {
	"max_hp": 5.0, "hp_regen": 0.5, "damage_pct": 10.0, "attack_speed_pct": 10.0, "range_pct": 10.0,
	"move_speed_pct": 10.0, "armor": 2.0, "pickup_range_pct": 20.0, "crit_chance": 5.0, "luck": 10.0,
}

var _arena: Arena
var _panel: PanelContainer
var _info: Label
var _god: Button
var _pause: Button
var _weapon_pick: OptionButton
var _enemy_pick: OptionButton
var _weapons: Array[WeaponData] = []
var _enemies: Array[EnemyData] = []
var _stat_labels := {}


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		queue_free()
		return
	layer = 30
	_arena = get_parent() as Arena
	for r in DataLibrary.load_all(WEAPONS_DIR):
		_weapons.append(r as WeaponData)
	_weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	for r in DataLibrary.load_all(ENEMIES_DIR):
		_enemies.append(r as EnemyData)
	_build_ui()
	_panel.visible = false
	Events.stats_changed.connect(_refresh_stats)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible
		_refresh_stats()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	_pause.text = "Onda pausada: SIM" if _arena.debug_wave_paused() else "Pausar onda"
	_info.text = "Onda %d  ·  %d inimigos\nArmas %d/%d  ·  Moedas %d" % [
		RunState.wave, get_tree().get_nodes_in_group("enemies").size(),
		RunState.weapons.size(), RunState.MAX_WEAPONS, RunState.materials]


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# --- actions ----------------------------------------------------------------------------------

func _heal() -> void:
	var p := _player()
	if p:
		p.heal(RunState.stats.get_value("max_hp"))


func _toggle_god() -> void:
	RunState.god_mode = not RunState.god_mode
	_god.text = "Invencível: %s" % ("SIM" if RunState.god_mode else "não")


func _give_weapon() -> void:
	if not RunState.has_weapon_slot():
		AudioManager.play_sfx("gun_empty", -8.0)
		return
	RunState.add_weapon(_weapons[_weapon_pick.selected])


func _change_stat(id: String, amount: float) -> void:
	RunState.stats.add(id, amount)
	Events.stats_changed.emit()


func _kill_all() -> void:
	var p := _player()
	var from := p.global_position if p else Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Enemy).take_damage(99999.0, from, false, 0.0)


func _spawn(count: int) -> void:
	var p := _player()
	if p == null or _enemies.is_empty():
		return
	var data := _enemies[_enemy_pick.selected]
	for i in count:
		var e: Enemy = ENEMY_SCENE.instantiate()
		p.get_parent().add_child(e)
		var at := p.global_position
		for attempt in 20:
			at = p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 150.0)
			if _arena.is_free(at, 12.0):
				break
		e.global_position = at
		e.setup(data, 1.0, 1.0)


func _go_wave(step: int) -> void:
	_arena.debug_goto_wave(RunState.wave - 1 + step)


# --- ui ---------------------------------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.custom_minimum_size.x = WIDTH
	_panel.offset_left = -WIDTH
	root.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)

	box.add_child(_title("TRAINER  (F1)"))
	_info = Label.new()
	box.add_child(_info)

	box.add_child(_title("Recursos"))
	_row(box, [["+100", func(): RunState.add_materials(100)], ["+1000", func(): RunState.add_materials(1000)]])
	_row(box, [["Curar tudo", _heal]])
	_god = _button("Invencível: não", _toggle_god)
	box.add_child(_god)

	box.add_child(_title("Armas"))
	_weapon_pick = _picker(box, _weapons.map(func(w: WeaponData) -> String: return w.display_name))
	_row(box, [["Dar arma", _give_weapon], ["Tirar última", RunState.remove_last_weapon]])

	box.add_child(_title("Atributos"))
	for id in STAT_STEPS:
		var step: float = STAT_STEPS[id]
		var line := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		line.add_child(_button("-", _change_stat.bind(id, -step)))
		line.add_child(_button("+", _change_stat.bind(id, step)))
		box.add_child(line)
		_stat_labels[id] = label

	box.add_child(_title("Onda"))
	_pause = _button("Pausar onda", _arena.debug_toggle_wave_pause)
	box.add_child(_pause)
	_row(box, [["Terminar onda", _arena.debug_finish_wave]])
	_row(box, [["< Onda", _go_wave.bind(-1)], ["Onda >", _go_wave.bind(1)]])

	box.add_child(_title("Inimigos"))
	_enemy_pick = _picker(box, _enemies.map(func(e: EnemyData) -> String: return e.display_name))
	_row(box, [["Spawnar 5", _spawn.bind(5)], ["Spawnar 20", _spawn.bind(20)]])
	_row(box, [["Matar todos", _kill_all]])

	box.add_child(_title("Câmera"))
	_row(box, [["Arena toda / seguir", _arena.debug_toggle_full_view]])

	box.add_child(_title("Velocidade do jogo"))
	_row(box, [["0.5x", _set_speed.bind(0.5)], ["1x", _set_speed.bind(1.0)], ["2x", _set_speed.bind(2.0)], ["4x", _set_speed.bind(4.0)]])
	box.add_child(_title("Run"))
	_row(box, [["Reiniciar run", func(): get_tree().reload_current_scene()]])


func _set_speed(scale: float) -> void:
	Engine.time_scale = scale


## RunState.stats does not exist until the arena starts the run, which happens after this node's _ready.
func _refresh_stats() -> void:
	if RunState.stats == null:
		return
	for id in _stat_labels:
		var info: Dictionary = Stats.INFO[id]
		(_stat_labels[id] as Label).text = "%s %s%s" % [info["label"], Stats.number(RunState.stats.get_value(id)), info["suffix"]]


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	return l


## Buttons never take keyboard focus, so the arrow keys keep moving the player while the panel is open.
func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_pressed)
	return b


func _row(parent: Control, buttons: Array) -> void:
	var line := HBoxContainer.new()
	for spec in buttons:
		line.add_child(_button(spec[0], spec[1]))
	parent.add_child(line)


func _picker(parent: Control, names: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.clip_text = true
	for n in names:
		o.add_item(n)
	parent.add_child(o)
	return o
