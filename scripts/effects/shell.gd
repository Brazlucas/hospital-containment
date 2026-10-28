class_name Shell
extends RefCounted
## A spent cartridge: it pops out of the weapon to the side, spins, falls to the floor, bounces once and fades after several seconds.
## Ported from the old game's player.gd. The art is the old game's "shell" animation (resources/items/gun_fx.tres).

const GUN_FX: SpriteFrames = preload("res://resources/items/gun_fx.tres")
const MAX_ALIVE := 120  ## rapid-fire weapons would otherwise pile them up
const FLOOR_DROP := 20.0  ## px from the weapon (torso height) down to the floor
const FLOOR_Z := -40  ## on the floor: above the stains, under the actors, like the gibs


## `from` is where the cartridge leaves the weapon, `aim` the direction it is shooting (radians).
static func eject(holder: Node, from: Vector2, aim: float, data: WeaponData) -> void:
	if holder.get_tree().get_nodes_in_group("shells").size() >= MAX_ALIVE:
		return
	var dir := Vector2.from_angle(aim)
	var side := Vector2(-dir.y, dir.x) * (1.0 if dir.x >= 0.0 else -1.0)  # the ejection port faces the same way as the player
	var s := AnimatedSprite2D.new()
	s.add_to_group("shells")
	s.sprite_frames = GUN_FX
	s.animation = &"shell"
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # drawn smaller than its pixels
	s.rotation = randf() * TAU
	if data.projectiles > 1:  # shotgun shells are fatter and red
		s.scale = Vector2.ONE * 0.85
		s.modulate = Color(1.3, 0.45, 0.4)
	elif data.damage >= 12.0:  # sniper rounds are longer
		s.scale = Vector2.ONE * 0.95
		s.modulate = Color(1.3, 1.2, 1.0)
	else:
		s.scale = Vector2.ONE * 0.7
		s.modulate = Color(1.3, 1.2, 1.0)  # brass: a bit brighter than the dark floor
	s.z_index = 29
	holder.add_child(s)
	s.global_position = from
	s.play("shell")
	var land := from + side * randf_range(8.0, 16.0) + dir * randf_range(-5.0, 2.0) + Vector2(0, FLOOR_DROP + randf_range(-3.0, 4.0))
	var peak := randf_range(7.0, 12.0)
	var flight := randf_range(0.32, 0.42)
	var tw := s.create_tween()
	tw.tween_method(func(k: float): s.global_position = from.lerp(land, k) + Vector2(0, -sin(k * PI) * peak), 0.0, 1.0, flight)
	tw.tween_method(func(k: float): s.global_position = land + side * 2.0 * k + Vector2(0, -sin(k * PI) * 3.0), 0.0, 1.0, 0.14)  # one small bounce
	tw.tween_callback(func(): s.z_index = FLOOR_Z)
	tw.tween_interval(randf_range(6.0, 10.0))
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.tween_callback(s.queue_free)
