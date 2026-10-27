extends Node2D
## PLACEHOLDER floor: dim hospital linoleum drawn in code. Replace with real top-down art
## (a tiled texture or TileMapLayer) without touching the rest of the arena.

const TILE := 16
const LIGHT := Color(0.30, 0.36, 0.34)
const DARK := Color(0.27, 0.33, 0.31)
const RIM := Color(0.10, 0.12, 0.13)


func _draw() -> void:
	var b: Rect2 = get_parent().bounds
	draw_rect(b.grow(96.0), Color(0.03, 0.03, 0.04))
	for y in ceili(b.size.y / TILE):
		for x in ceili(b.size.x / TILE):
			var color := LIGHT if (x + y) % 2 == 0 else DARK
			draw_rect(Rect2(b.position + Vector2(x, y) * TILE, Vector2(TILE, TILE)).intersection(b), color)
	draw_rect(b, RIM, false, 3.0)
