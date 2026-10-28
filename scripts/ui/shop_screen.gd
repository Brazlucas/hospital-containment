extends CanvasLayer
## The shop, between the skill picks and the next wave: STOCK random items from resources/data/shop/ to buy with
## materials, a paid reroll, and a button to move on. Bought items apply at once through RunState.buy().
## The cards are compact (name, icon, one key number, price); the DETAIL panel under them shows everything about
## the card that has the focus or the mouse: description, every stat, and the synergies the item would advance.

signal finished

const STOCK := 4
const SHOP_DIR := "res://resources/data/shop"
const REROLL_BASE := 4  ## reroll price at wave 1; grows with the wave and with each reroll
const CARD_SIZE := Vector2(108, 106)
const DETAIL_SIZE := Vector2(456, 90)
const FONT_SMALL := 9
const FONT_TEXT := 10
const POSITIVE := Color(0.55, 0.95, 0.6)
const NEGATIVE := Color(1.0, 0.5, 0.5)
const MUTED := Color(0.62, 0.66, 0.68)
## One colour per weapon stat, so a row is recognised at a glance (the name and the number share it).
const STAT_COLORS := {
	"Dano": Color(1.0, 0.45, 0.4), "Cadência": Color(1.0, 0.85, 0.3), "Alcance": Color(0.45, 0.75, 1.0),
	"Dispersão": Color(0.78, 0.6, 1.0), "Perfura": Color(0.4, 0.9, 0.9), "Empurra": Color(1.0, 0.65, 0.3),
	"Crítico": Color(1.0, 0.5, 0.8), "Área": Color(1.0, 0.6, 0.3), "DPS": Color(0.55, 0.95, 0.6), "Arco": Color(0.45, 0.75, 1.0),
}
const ACCENT := Color(0.45, 0.78, 1.0)
const WEAPON_ACCENT := Color(1.0, 0.78, 0.25)

var _pool: Array[ShopItemData] = []
var _offers: Array[ShopItemData] = []
var _rerolls := 0
var _selected := 0  ## the card the detail panel is showing
var _title: Label
var _coins: Label
var _cards: HBoxContainer
var _detail: PanelContainer
var _detail_name: Label
var _detail_tags: Label
var _detail_text: Label
var _detail_stats: VBoxContainer
var _detail_synergies: VBoxContainer
var _reroll: Button
var _go: Button


func _ready() -> void:
	layer = 20
	visible = false
	for r in DataLibrary.load_all(SHOP_DIR):
		_pool.append(r as ShopItemData)
	_build_ui()
	Events.materials_changed.connect(_on_materials)


func open() -> void:
	_rerolls = 0
	_selected = 0
	visible = true
	_title.text = "LOJA  ·  ONDA %d" % RunState.wave
	_stock()
	_go.grab_focus.call_deferred()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	head.add_child(_title)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/ui/coin_icon.png")
	coin.custom_minimum_size = Vector2(16, 16)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(coin)
	_coins = Label.new()
	_coins.add_theme_font_size_override("font_size", 14)
	head.add_child(_coins)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards)
	_build_detail(box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(foot)
	_reroll = Button.new()
	_reroll.pressed.connect(_on_reroll)
	foot.add_child(_reroll)
	_go = Button.new()
	_go.text = "PRÓXIMA ONDA"
	_go.pressed.connect(_on_go)
	foot.add_child(_go)


## The panel under the cards: name, families and description on the left, the stats in the middle, synergies on the right.
func _build_detail(box: VBoxContainer) -> void:
	_detail = PanelContainer.new()
	_detail.custom_minimum_size = DETAIL_SIZE
	box.add_child(_detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_detail.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(122, 0)
	left.add_theme_constant_override("separation", 1)
	row.add_child(left)
	_detail_name = _text_label("", FONT_TEXT, Color.WHITE)
	_detail_tags = _wrap_label("", FONT_SMALL, MUTED)
	_detail_text = _wrap_label("", FONT_SMALL, MUTED)
	for l in [_detail_name, _detail_tags, _detail_text]:
		left.add_child(l)
	_detail_stats = VBoxContainer.new()
	_detail_stats.custom_minimum_size = Vector2(192, 0)
	_detail_stats.add_theme_constant_override("separation", 0)
	row.add_child(_detail_stats)
	_detail_synergies = VBoxContainer.new()
	_detail_synergies.custom_minimum_size = Vector2(112, 0)
	_detail_synergies.add_theme_constant_override("separation", 1)
	row.add_child(_detail_synergies)


func _on_materials(total: int) -> void:
	_coins.text = str(total)
	if visible:
		_refresh()


func _reroll_price() -> int:
	return REROLL_BASE + RunState.wave + _rerolls * 2


## Picks STOCK different items (weighted) among those still available this run.
func _stock() -> void:
	var candidates: Array[ShopItemData] = []
	candidates.assign(_pool.filter(func(i: ShopItemData) -> bool: return RunState.is_available(i)))
	_offers.clear()
	while _offers.size() < STOCK and not candidates.is_empty():
		var total := 0.0
		for i in candidates:
			total += i.weight
		var r := randf() * total
		var picked: ShopItemData = candidates.back()
		for i in candidates:
			r -= i.weight
			if r <= 0.0:
				picked = i
				break
		_offers.append(picked)
		candidates.erase(picked)
	_coins.text = str(RunState.materials)
	_selected = 0
	_rebuild_cards()


func _rebuild_cards() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for i in _offers.size():
		_cards.add_child(_make_card(i))
	_refresh()


## Updates what depends on the wallet and on what the player owns: the cards' look and numbers, the reroll button,
## the synergy strip and the detail panel.
func _refresh() -> void:
	for c in _cards.get_children():
		var item: ShopItemData = _offers[c.get_index()]
		var sold: bool = c.get_meta("sold", false)
		var ok := not sold and RunState.can_buy(item)
		c.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)
		_update_tag(c.get_meta("tag") as Label, item)
		(c.get_meta("price") as Label).text = _price_text(item, sold)
		(c.get_meta("price") as Label).add_theme_color_override("font_color", POSITIVE if ok else NEGATIVE)
	_reroll.text = "TROCAR  %d" % _reroll_price()
	_reroll.disabled = RunState.materials < _reroll_price()
	_render_detail()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_render_detail()


## Fills the detail panel with the selected card's item.
func _render_detail() -> void:
	if _offers.is_empty():
		return
	var item := _offers[clampi(_selected, 0, _offers.size() - 1)]
	var accent := _accent_of(item)
	_detail.add_theme_stylebox_override("panel", _card_style(accent, false))
	_detail_name.text = item.display_name
	_detail_name.add_theme_color_override("font_color", accent.lightened(0.55))
	_detail_tags.text = _tag_text(item)
	_detail_text.text = item.description
	for c in _detail_stats.get_children():
		_detail_stats.remove_child(c)
		c.queue_free()
	var lines := item.effect_lines()
	if item.kind == ShopItemData.Kind.WEAPON:
		var grid := GridContainer.new()  # two label/value pairs per row
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 1)
		for line in lines:
			var color: Color = STAT_COLORS.get(line["label"], MUTED)
			grid.add_child(_cell(line["label"], color, 56))
			grid.add_child(_cell(line["value"], color.lightened(0.45), 34))
		_detail_stats.add_child(grid)
	else:
		for line in lines:
			_detail_stats.add_child(_text_label(line["text"], FONT_TEXT, POSITIVE if line["positive"] else NEGATIVE))
	for c in _detail_synergies.get_children():
		_detail_synergies.remove_child(c)
		c.queue_free()
	_detail_synergies.add_child(_text_label("SINERGIAS", FONT_SMALL, MUTED))
	var hints := RunState.synergy_hints(item)
	if hints.is_empty():
		_detail_synergies.add_child(_wrap_label("nenhuma nova", FONT_SMALL, MUTED))
	for h in hints.slice(0, 2):
		_detail_synergies.add_child(_wrap_label(h[0], FONT_SMALL, h[1]))
	for s in RunState.active_synergies.slice(0, 2):  # and what is already on, so the whole picture is here
		_detail_synergies.add_child(_wrap_label("✓ %s" % s.display_name, FONT_SMALL, s.color.darkened(0.2)))


func _accent_of(item: ShopItemData) -> Color:
	return WEAPON_ACCENT if item.kind == ShopItemData.Kind.WEAPON else ACCENT


## "ARMA · armas de fogo · pistolas"
func _tag_text(item: ShopItemData) -> String:
	var names := PackedStringArray(["ARMA" if item.kind == ShopItemData.Kind.WEAPON else "ITEM"])
	for t in item.all_tags():
		if t != "arma":
			names.append(SynergyData.tag_name(t))
	return " · ".join(names)


## The top line of a card: its kind, how many the player already has, and a star when buying it would start (☆)
## or switch on (★) a synergy, in that synergy's colour. The details are in the panel below.
func _update_tag(label: Label, item: ShopItemData) -> void:
	var kind := "ARMA" if item.kind == ShopItemData.Kind.WEAPON else "ITEM"
	var owned: int = RunState.purchases.get(item.id, 0)
	var text := kind + ("  x%d" % owned if owned > 0 else "")
	var hint := RunState.synergy_hint(item)
	if hint.is_empty():
		label.add_theme_color_override("font_color", _accent_of(item))
	else:
		text += "  ★" if hint[2] else "  ☆"
		label.add_theme_color_override("font_color", hint[1])
	label.text = text


func _price_text(item: ShopItemData, sold: bool) -> String:
	if sold:
		return "COMPRADO"
	if not RunState.is_available(item):
		return "SEM ESPAÇO" if item.kind == ShopItemData.Kind.WEAPON else "ESGOTADO"
	return str(RunState.price_of(item))


## A compact card: kind, name, icon, one key number (a weapon's DPS, an item's first effect), a synergy hint and the price.
## Everything else is in the detail panel, which follows the focus.
func _make_card(index: int) -> Button:
	var item := _offers[index]
	var accent := _accent_of(item)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = true  # whatever happens inside, nothing spills out of the card
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		card.add_theme_stylebox_override(state, _card_style(accent, state == "hover" or state == "focus" or state == "hover_pressed"))
	card.pressed.connect(_on_card_pressed.bind(card, index))
	card.mouse_entered.connect(_on_card_entered.bind(index))
	card.focus_entered.connect(_on_card_entered.bind(index))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	card.add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	margin.add_child(col)
	var tag_label := _label("", FONT_SMALL, accent)
	col.add_child(tag_label)
	card.set_meta("tag", tag_label)
	col.add_child(_wrap_label(item.display_name, FONT_TEXT, accent.lightened(0.55), HORIZONTAL_ALIGNMENT_CENTER))
	var icon_tex := item.display_icon()
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(0, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)
	col.add_child(_key_line(item))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var price := _label("", FONT_TEXT, POSITIVE)
	col.add_child(price)
	card.set_meta("price", price)
	return card


func _on_card_entered(index: int) -> void:
	AudioManager.play_sfx("ui_move", -12.0)
	_select(index)


## The one number on a card: a weapon's DPS (the quickest way to compare two guns), or an item's first effect.
func _key_line(item: ShopItemData) -> Label:
	var lines := item.effect_lines()
	if item.kind == ShopItemData.Kind.WEAPON:
		for line in lines:
			if line["label"] == "DPS":
				return _label("DPS %s" % line["value"], FONT_SMALL, STAT_COLORS["DPS"])
	if not lines.is_empty():
		return _label(lines[0]["text"], FONT_SMALL, POSITIVE if lines[0]["positive"] else NEGATIVE)
	return _label("", FONT_SMALL, MUTED)


## A stat name or number in the detail grid.
func _cell(text: String, color: Color, min_width: float) -> Label:
	var l := _text_label(text, FONT_TEXT, color)
	l.custom_minimum_size = Vector2(min_width, 0)
	return l


func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09).lerp(accent, 0.28 if highlighted else 0.14)
	style.border_color = accent.lightened(0.3) if highlighted else accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	return style


## A centred single line (cards): it never wraps or grows, it gets cut instead.
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := _text_label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CARD_SIZE.x - 14.0, 0)
	return l


## A label that wraps onto more lines instead of being cut off.
func _wrap_label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _text_label(text, font_size, color)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	return l


## A left-aligned label that ignores the mouse (detail panel).
func _text_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _on_card_pressed(card: Button, index: int) -> void:
	if card.get_meta("sold", false) or not RunState.buy(_offers[index]):
		AudioManager.play_sfx("gun_empty", -8.0)
		return
	AudioManager.play_sfx("ui_select", -6.0)
	card.set_meta("sold", true)  # materials_changed has already refreshed the cards; redo it with the flag set
	_refresh()


func _on_reroll() -> void:
	if RunState.materials < _reroll_price():
		return
	RunState.spend_materials(_reroll_price())
	_rerolls += 1
	AudioManager.play_sfx("ui_select", -6.0)
	_stock()


func _on_go() -> void:
	AudioManager.play_sfx("ui_back", -6.0)
	visible = false
	finished.emit()
