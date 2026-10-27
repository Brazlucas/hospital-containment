extends CanvasLayer
## In-run HUD, built in code: HP, level / XP, wave and clock, materials, and the end-of-run panel.
## It only listens to Events, so it works no matter how the arena is set up.

const FONT_SIZE := 10

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _wave_label: Label
var _time_label: Label
var _materials_label: Label
var _result: PanelContainer
var _result_title: Label
var _result_body: Label
var _last_second := -1


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left(root)
	_build_top_center(root)
	_build_top_right(root)
	_build_result(root)
	Events.player_hp_changed.connect(_on_hp)
	Events.xp_changed.connect(_on_xp)
	Events.materials_changed.connect(_on_materials)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_time_changed.connect(_on_time)
	Events.run_ended.connect(_on_run_ended)


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
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [ceili(hp), roundi(max_hp)]


func _on_xp(level: int, xp: float, needed: float) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_level_label.text = "NV %d" % level


func _on_materials(total: int) -> void:
	_materials_label.text = str(total)


func _on_wave_started(wave: int, total: int) -> void:
	_wave_label.text = "ONDA %d / %d" % [wave, total]


func _on_time(seconds_left: float) -> void:
	var s := ceili(seconds_left)
	if s != _last_second:  # the clock label only changes once a second
		_last_second = s
		_time_label.text = "%d" % s


func _on_run_ended(victory: bool) -> void:
	_result_title.text = "VOCÊ SOBREVIVEU" if victory else "VOCÊ MORREU"
	_result_body.text = "Onda %d  ·  %d abates  ·  Nível %d\n\nENTER para recomeçar" % [RunState.wave, RunState.kills, RunState.level]
	_result.visible = true
