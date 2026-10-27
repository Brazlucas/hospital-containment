class_name ReflectionMap
extends Node
## The floor map behind every reflection (see reflection.gdshader), in world space:
## R = there is floor here (not a wall or furniture), G = how wet it is.
## Wetness comes from the blood painted in the arena background, from water puddles, and from the blood
## stains that appear during the run, so zombies reflect strongly in every pool.

const MATERIAL: ShaderMaterial = preload("res://resources/materials/reflection.tres")
const TEXEL := 2.0  ## world px per map texel
const RED_THRESHOLD := 0.07  ## how much redder than green/blue a painted pixel must be to count as blood
const UPLOAD_INTERVAL := 0.2  ## seconds between texture uploads while stains keep arriving

var _img: Image
var _tex: ImageTexture
var _dirty := false
var _since := 0.0


## `floor_rect` and `blockers` are in world px; the map covers the whole background.
func build(background: Texture2D, art_scale: float, floor_rect: Rect2, blockers: Array[Rect2]) -> void:
	add_to_group("reflection_map")
	var size := background.get_size() * art_scale
	_img = Image.create(ceili(size.x / TEXEL), ceili(size.y / TEXEL), false, Image.FORMAT_RGBA8)
	_img.fill_rect(_texels(floor_rect), Color(1, 0, 0, 1))
	for r in blockers:
		_img.fill_rect(_texels(r), Color(0, 0, 0, 1))
	_wet_from_painting(background, art_scale)
	_tex = ImageTexture.create_from_image(_img)
	MATERIAL.set_shader_parameter("refl_map", _tex)
	MATERIAL.set_shader_parameter("map_origin", Vector2.ZERO)
	MATERIAL.set_shader_parameter("map_size", size)


## Marks a round patch of floor as wet (water puddle, fresh blood). `amount` 1 = a mirror.
func stamp_wet(world_pos: Vector2, radius: float, amount := 0.95) -> void:
	var c := world_pos / TEXEL
	var r := radius / TEXEL
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if x < 0 or y < 0 or x >= _img.get_width() or y >= _img.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(c) > r:
				continue
			var px := _img.get_pixel(x, y)
			if px.r > 0.5 and px.g < amount:
				px.g = amount
				_img.set_pixel(x, y, px)
				_dirty = true


func _process(delta: float) -> void:
	if not _dirty:
		return
	_since += delta
	if _since >= UPLOAD_INTERVAL:
		_since = 0.0
		_dirty = false
		_tex.update(_img)


func _texels(r: Rect2) -> Rect2i:
	return Rect2i(floori(r.position.x / TEXEL), floori(r.position.y / TEXEL), ceili(r.size.x / TEXEL) + 1, ceili(r.size.y / TEXEL) + 1)


## Every reddish pixel of the painted floor (the blood pools) becomes wet floor, with soft edges.
func _wet_from_painting(background: Texture2D, art_scale: float) -> void:
	var src := background.get_image()
	if src == null:
		return
	var step := TEXEL / art_scale  # background px per texel
	var wet: Array[Vector2i] = []
	for y in _img.get_height():
		for x in _img.get_width():
			var px := _img.get_pixel(x, y)
			if px.r < 0.5:
				continue
			var c := src.get_pixel(mini(int((x + 0.5) * step), src.get_width() - 1), mini(int((y + 0.5) * step), src.get_height() - 1))
			var red := c.r - (c.g + c.b) * 0.5
			if red > RED_THRESHOLD:
				px.g = clampf(red * 4.0, 0.0, 0.95)
				_img.set_pixel(x, y, px)
				wet.append(Vector2i(x, y))
	for p in wet:  # soften the edge: neighbours get half the wetness
		var g := _img.get_pixelv(p).g * 0.5
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= _img.get_width() or q.y >= _img.get_height():
				continue
			var px := _img.get_pixelv(q)
			if px.r > 0.5 and px.g < g:
				px.g = g
				_img.set_pixelv(q, px)
