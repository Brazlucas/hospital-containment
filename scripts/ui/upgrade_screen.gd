extends CanvasLayer
## Level-up picks between waves: one offer of 3 upgrades per level gained during the wave.
## The pool is every .tres in resources/data/upgrades/.

signal finished

const CHOICES := 3
const UPGRADES_DIR := "res://resources/data/upgrades"

var _pool: Array[UpgradeData] = []
var _title: Label
var _cards: HBoxContainer


func _ready() -> void:
	layer = 20
	visible = false
	for r in DataLibrary.load_all(UPGRADES_DIR):
		_pool.append(r as UpgradeData)
	_build_ui()


## Starts the picks, or just emits `finished` when no level was gained.
func open() -> void:
	if RunState.pending_levels <= 0:
		finished.emit()
		return
	visible = true
	_offer()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	box.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	box.add_child(_cards)


func _offer() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_title.text = "NÍVEL %d  ·  escolha uma melhoria" % (RunState.level - RunState.pending_levels + 1)
	for u in _roll():
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 90)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 10)
		var owned := RunState.stacks_of(u.id)
		b.text = "%s%s\n\n%s" % [u.display_name, " (x%d)" % owned if owned > 0 else "", u.effect_text()]
		b.tooltip_text = u.flavor
		b.pressed.connect(_pick.bind(u))
		_cards.add_child(b)
	if _cards.get_child_count() > 0:
		_cards.get_child(0).grab_focus.call_deferred()


## Weighted pick without repeats, skipping upgrades already at their max stacks.
func _roll() -> Array[UpgradeData]:
	var candidates: Array[UpgradeData] = []
	candidates.assign(_pool.filter(func(u: UpgradeData) -> bool: return u.max_stacks <= 0 or RunState.stacks_of(u.id) < u.max_stacks))
	var out: Array[UpgradeData] = []
	while out.size() < CHOICES and not candidates.is_empty():
		var total := 0.0
		for u in candidates:
			total += u.weight
		var r := randf() * total
		var picked: UpgradeData = candidates.back()  # fallback if float rounding leaves r above 0
		for u in candidates:
			r -= u.weight
			if r <= 0.0:
				picked = u
				break
		out.append(picked)
		candidates.erase(picked)
	return out


func _pick(u: UpgradeData) -> void:
	RunState.take_upgrade(u)
	RunState.pending_levels -= 1
	if RunState.pending_levels > 0:
		_offer()
	else:
		visible = false
		finished.emit()
