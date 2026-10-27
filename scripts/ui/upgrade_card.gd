class_name UpgradeCard
extends Button
## One level-up choice, drawn as a collectible card. The face (name, effects, flavour text) is rendered in a
## SubViewport and shown through card.gdshader, which tilts it toward the pointer in perspective and adds the
## rarity's effect: foil, holographic, polychrome or gold. It is a Button, so mouse, keyboard and gamepad
## selection work as usual (`pressed` = picked).

const CARD_SIZE := Vector2(110, 150)
const PAD := 12.0  ## transparent margin around the card, so a tilted card and its shadow stay inside the quad
const FULL := CARD_SIZE + Vector2(PAD, PAD) * 2.0
const SHADER: Shader = preload("res://scripts/ui/card.gdshader")
const FONT_SMALL := 8
const FONT_TEXT := 10
const POSITIVE := Color(0.55, 0.95, 0.6)
const NEGATIVE := Color(1.0, 0.5, 0.5)

var offer: UpgradeOffer  ## set before the card enters the tree
var deal_delay := 0.0  ## seconds before the card is dealt onto the table

var _viewport: SubViewport
var _mat: ShaderMaterial
var _tilt := Vector2.ZERO
var _lift := 0.0
var _entrance := 0.0
var _deal_rotation := randf_range(-0.2, 0.2)
var _time := randf() * 10.0


func _ready() -> void:
	custom_minimum_size = FULL
	pivot_offset = FULL * 0.5
	flat = true
	focus_mode = Control.FOCUS_ALL
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_build_face()
	_build_view()
	mouse_entered.connect(_on_hover)
	focus_entered.connect(_on_hover)
	pressed.connect(func(): AudioManager.play_sfx("ui_select", -6.0))
	scale = Vector2.ONE * 0.7
	rotation = _deal_rotation
	modulate.a = 0.0
	create_tween().tween_property(self, "_entrance", 1.0, 0.32).set_delay(deal_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	var pointer := is_hovered()
	var target := Vector2.ZERO
	if pointer:
		target = (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
	elif has_focus():
		target = Vector2(sin(_time * 1.4), cos(_time * 1.1)) * 0.4  # selected by keyboard: sways on its own
	var k := 1.0 - exp(-delta * 10.0)
	_tilt = _tilt.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), k)
	_lift = lerpf(_lift, 1.0 if (pointer or has_focus()) else 0.0, k)
	scale = Vector2.ONE * lerpf(0.7, 1.0, _entrance) * (1.0 + 0.07 * _lift)
	rotation = _deal_rotation * (1.0 - clampf(_entrance, 0.0, 1.0))
	modulate.a = clampf(_entrance * 1.6, 0.0, 1.0)
	_mat.set_shader_parameter("tilt", _tilt)
	_mat.set_shader_parameter("lift", _lift)


func _on_hover() -> void:
	AudioManager.play_sfx("ui_move", -12.0)


## The flat card, laid out with ordinary controls inside a SubViewport (so it can be warped as a texture).
func _build_face() -> void:
	var tier := offer.tier
	var accent: Color = Rarity.ACCENTS[tier]
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FULL)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var panel := PanelContainer.new()
	panel.position = Vector2(PAD, PAD)
	panel.custom_minimum_size = CARD_SIZE
	panel.size = CARD_SIZE
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09).lerp(accent, 0.16)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(7)
	panel.add_theme_stylebox_override("panel", style)
	_viewport.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var owned := RunState.stacks_of(offer.upgrade.id)
	box.add_child(_label("%s%s" % [Rarity.NAMES[tier].to_upper(), "  ·  x%d" % owned if owned > 0 else ""], FONT_SMALL, accent))
	box.add_child(_label(offer.upgrade.display_name, FONT_TEXT, accent.lightened(0.55)))
	if offer.upgrade.icon:
		var icon := TextureRect.new()
		icon.texture = offer.upgrade.icon
		icon.custom_minimum_size = Vector2(0, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
	var rule := ColorRect.new()
	rule.color = accent * Color(1, 1, 1, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	for line in Stats.lines(offer.modifiers()):
		box.add_child(_label(line["text"], FONT_TEXT, POSITIVE if line["positive"] else NEGATIVE))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label(offer.upgrade.flavor, FONT_SMALL, Color(0.62, 0.66, 0.68)))


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_SIZE.x - 18.0, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## The TextureRect that shows the face through the card shader.
func _build_view() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("rarity", offer.tier)
	_mat.set_shader_parameter("seed", randf() * 10.0)
	_mat.set_shader_parameter("size", FULL)
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.material = _mat
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
