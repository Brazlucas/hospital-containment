extends CanvasLayer
## Skill picks after every finished wave: PICKS_PER_WAVE offers of 3 cards, like Brotato. Each card is an upgrade at a
## rarity (see Rarity): rarer cards give bigger bonuses and shimmer more. The pool is every .tres in resources/data/upgrades/.

signal finished

const CHOICES := 3
const PICKS_PER_WAVE := 2
const UPGRADES_DIR := "res://resources/data/upgrades"

var _pool: Array[UpgradeData] = []
var _picks_left := 0
var _title: Label
var _cards: HBoxContainer


func _ready() -> void:
	layer = 20
	visible = false
	for r in DataLibrary.load_all(UPGRADES_DIR):
		_pool.append(r as UpgradeData)
	_build_ui()


## Starts the picks of the wave that just ended.
func open() -> void:
	_picks_left = PICKS_PER_WAVE
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
	_cards.add_theme_constant_override("separation", 4)
	box.add_child(_cards)


func _offer() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_title.text = "ONDA %d CONCLUÍDA  ·  escolha uma habilidade (%d/%d)" % [RunState.wave, PICKS_PER_WAVE - _picks_left + 1, PICKS_PER_WAVE]
	var offers := _roll()
	for i in offers.size():
		var card := UpgradeCard.new()
		card.offer = offers[i]
		card.deal_delay = i * 0.09
		card.pressed.connect(_pick.bind(offers[i]))
		_cards.add_child(card)
	if _cards.get_child_count() > 0:
		_cards.get_child(0).grab_focus.call_deferred()


## Different upgrades (weighted, skipping those at their max stacks), each at a rarity rolled by the wave and luck.
func _roll() -> Array[UpgradeOffer]:
	var candidates: Array[UpgradeData] = []
	candidates.assign(_pool.filter(func(u: UpgradeData) -> bool: return u.max_stacks <= 0 or RunState.stacks_of(u.id) < u.max_stacks))
	var luck := RunState.stats.get_value("luck")
	var out: Array[UpgradeOffer] = []
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
		out.append(UpgradeOffer.new(picked, Rarity.roll(RunState.wave, luck)))
		candidates.erase(picked)
	return out


func _pick(offer: UpgradeOffer) -> void:
	RunState.take_upgrade(offer.upgrade, offer.tier)
	_picks_left -= 1
	if _picks_left > 0:
		_offer()
	else:
		visible = false
		finished.emit()
