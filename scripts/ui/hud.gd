extends CanvasLayer
## In-run HUD, built in code: HP, level / XP, wave and clock, materials, and the end-of-run panel.
## It only listens to Events, so it works no matter how the arena is set up.

const FONT_SIZE := 10
const STREAK_WINDOW := 2.5  ## seconds without a kill before the streak ends
const STREAK_MIN := 3  ## the counter only shows from here
const MILESTONES := {10: "CHACINA!", 25: "MASSACRE!", 50: "IMPARÁVEL!", 100: "LENDÁRIO!"}
const LOW_HP := 0.3
const BANNER_SHADER := preload("res://scripts/ui/banner_text.gdshader")

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _wave_label: Label
var _time_label: Label
var _ambience_label: Label
var _ambience_tween: Tween
var _materials_label: Label
var _result: PanelContainer
var _result_title: Label
var _result_body: Label
var _last_second := -1
var _shake := 0.0  ## 1 right after a hit, fades to 0: the whole HUD twitches while it lasts
var _root: Control
var _streak := 0
var _streak_t := 0.0
var _streak_label: Label
var _hp_ratio := 1.0
var _time := 0.0
var _last_materials := 0
var _synergy_box: VBoxContainer


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root
	_build_top_left(root)
	_build_top_center(root)
	_build_top_right(root)
	_build_streak(root)
	_build_synergies(root)
	_build_result(root)
	Events.player_hp_changed.connect(_on_hp)
	Events.xp_changed.connect(_on_xp)
	Events.materials_changed.connect(_on_materials)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_time_changed.connect(_on_time)
	Events.ambience_changed.connect(_on_ambience)
	Events.run_ended.connect(_on_run_ended)
	Events.player_hurt.connect(_on_hurt)
	Events.enemy_killed.connect(_on_kill)
	Events.wave_finished.connect(_on_wave_finished)
	Events.synergies_changed.connect(_refresh_synergies)
	Events.synergy_activated.connect(_on_synergy_activated)


## The HUD spasms when the player is hit, as if the character felt it: it jitters and tilts a little, and the bar flashes.
func _on_hurt(amount: float) -> void:
	_shake = clampf(0.5 + amount * 0.12, 0.5, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_tick_streak(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.4)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 5.0 * _shake
		rotation = randf_range(-1.0, 1.0) * 0.008 * _shake
		if _shake <= 0.0:
			offset = Vector2.ZERO
			rotation = 0.0
	# the bar flashes on a hit, and throbs red while health is low
	var throb := (0.5 + 0.5 * sin(_time * 7.0)) * 0.6 if _hp_ratio > 0.0 and _hp_ratio < LOW_HP else 0.0
	_hp_bar.modulate = Color.WHITE.lerp(Color(2.2, 0.5, 0.5), maxf(_shake, throb))


func _build_top_left(root: Control) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(6, 4)
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)
	_hp_bar = _make_bar(Vector2(96, 12), Color(0.75, 0.12, 0.16))
	_hp_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bar.add_child(_hp_label)
	box.add_child(_hp_bar)
	_xp_bar = _make_bar(Vector2(96, 5), Color(0.35, 0.6, 0.9))
	box.add_child(_xp_bar)
	_level_label = _label("NV 1")
	box.add_child(_level_label)


func _build_top_center(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 4
	root.add_child(box)
	_wave_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_time_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_time_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_wave_label)
	box.add_child(_time_label)
	_ambience_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_ambience_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	_ambience_label.modulate.a = 0.0
	box.add_child(_ambience_label)


func _build_top_right(root: Control) -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -6.0
	box.offset_top = 4.0
	root.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/coin_icon.png")
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	_materials_label = _label("0")
	box.add_child(_materials_label)


func _build_streak(root: Control) -> void:
	_streak_label = _label("", HORIZONTAL_ALIGNMENT_RIGHT)
	_streak_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_streak_label.offset_right = -6.0
	_streak_label.offset_top = 24.0
	_streak_label.visible = false
	root.add_child(_streak_label)


## Kills in quick succession build a streak: the counter punches on every kill, warms up from white to red,
## and some round numbers get a shout.
func _on_kill(_enemy: Node2D) -> void:
	_streak += 1
	_streak_t = STREAK_WINDOW
	if MILESTONES.has(_streak):
		_banner(MILESTONES[_streak], Color(1.0, 0.8, 0.25), 13, -30, Color(1.0, 1.0, 0.75))
	if _streak < STREAK_MIN:
		return
	_streak_label.visible = true
	_streak_label.text = "%d ABATES" % _streak
	var color := Color(1.0, 0.35, 0.3) if _streak >= 40 else Color(1.0, 0.6, 0.25) if _streak >= 20 \
			else Color(1.0, 0.85, 0.3) if _streak >= 10 else Color(0.95, 0.95, 0.95)
	_streak_label.add_theme_color_override("font_color", color)
	_streak_label.pivot_offset = Vector2(_streak_label.size.x, 0.0)  # grows from its right edge
	_streak_label.scale = Vector2.ONE * 1.4
	create_tween().tween_property(_streak_label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)


func _tick_streak(delta: float) -> void:
	if _streak <= 0:
		return
	_streak_t -= delta
	_streak_label.modulate.a = clampf(_streak_t / 0.6, 0.0, 1.0)  # fades out over the last moments
	if _streak_t <= 0.0:
		_streak = 0
		_streak_label.visible = false
		_streak_label.modulate.a = 1.0


## A big word that pops in, holds and fades: wave starts and ends, streak milestones.
func _banner(text: String, color: Color, size: int, y_offset: float, accent := Color(1.0, 0.95, 0.7)) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(320, 32)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -160.0
	l.offset_right = 160.0
	l.offset_top = y_offset
	l.offset_bottom = y_offset + 32.0
	l.pivot_offset = Vector2(160, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	var mat := ShaderMaterial.new()
	mat.shader = BANNER_SHADER
	mat.set_shader_parameter("accent", accent)
	l.material = mat
	l.modulate.a = 0.0
	l.scale = Vector2.ONE * 2.0
	_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


## The synergies that are on, listed in the bottom-left corner in their own colours.
func _build_synergies(root: Control) -> void:
	_synergy_box = VBoxContainer.new()
	_synergy_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_synergy_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_synergy_box.offset_left = 6.0
	_synergy_box.offset_bottom = -4.0
	_synergy_box.add_theme_constant_override("separation", 0)
	_synergy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_synergy_box)


func _refresh_synergies() -> void:
	for c in _synergy_box.get_children():
		_synergy_box.remove_child(c)
		c.queue_free()
	for s in RunState.active_synergies:
		var l := _label("★ %s" % s.display_name.to_upper())
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", s.color)
		l.add_theme_constant_override("outline_size", 2)
		_synergy_box.add_child(l)


func _on_synergy_activated(s: SynergyData) -> void:
	_banner("SINERGIA: %s" % s.display_name.to_upper(), s.color, 13, -10, s.color.lightened(0.5))


func _build_result(root: Control) -> void:
	_result = PanelContainer.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_result.add_child(box)
	_result_title = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_result_title.add_theme_font_size_override("font_size", 18)
	_result_body = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_result_title)
	box.add_child(_result_body)
	root.add_child(_result)


func _label(text: String, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l


func _make_bar(size: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.05, 0.07, 0.85)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", front)
	return bar


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_ratio = hp / maxf(max_hp, 1.0)
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [ceili(hp), roundi(max_hp)]


func _on_xp(level: int, xp: float, needed: float) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_level_label.text = "NV %d" % level


func _on_materials(total: int) -> void:
	_materials_label.text = str(total)
	if total > _last_materials:  # the counter pops when coins arrive
		_materials_label.pivot_offset = _materials_label.size * 0.5
		_materials_label.scale = Vector2.ONE * 1.35
		create_tween().tween_property(_materials_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last_materials = total


func _on_wave_started(wave: int, total: int) -> void:
	_wave_label.text = "ONDA %d / %d" % [wave, total]
	_banner("ONDA %d" % wave, Color(0.95, 0.9, 0.8), 20, -60, Color(1.0, 0.85, 0.45))


func _on_wave_finished(_wave: int) -> void:
	_banner("ONDA CONCLUÍDA", Color(0.55, 0.95, 0.6), 16, -60, Color(0.85, 1.0, 0.85))
	_streak = 0
	_streak_label.visible = false


func _on_time(seconds_left: float) -> void:
	var s := ceili(seconds_left)
	if s != _last_second:  # the clock label only changes once a second
		_last_second = s
		_time_label.text = "%d" % s


## The atmosphere's name shows for a few seconds under the clock.
func _on_ambience(display_name: String) -> void:
	_ambience_label.text = display_name.to_upper()
	if _ambience_tween:
		_ambience_tween.kill()
	_ambience_label.modulate.a = 1.0
	_ambience_tween = create_tween()
	_ambience_tween.tween_interval(3.0)
	_ambience_tween.tween_property(_ambience_label, "modulate:a", 0.0, 1.0)


func _on_run_ended(victory: bool) -> void:
	_result_title.text = "VOCÊ SOBREVIVEU" if victory else "VOCÊ MORREU"
	_result_body.text = "Onda %d  ·  %d abates  ·  Nível %d\n\nENTER ou A para recomeçar" % [RunState.wave, RunState.kills, RunState.level]
	_result.visible = true
