class_name Gore
extends RefCounted
## Blood and gibs, ported from the old game's enemy.gd (no iso squash). Everything is added to `holder`
## (the arena's entity layer) or to the "decals" group node, so it outlives the enemy that made it.

const STAINS: Array[Texture2D] = [
	preload("res://assets/environment/decal/decal_02.png"), preload("res://assets/environment/decal/decal_03.png"),
	preload("res://assets/environment/decal/decal_04.png"), preload("res://assets/environment/decal/decal_05.png"),
]
const GIBS: Array[Texture2D] = [
	preload("res://assets/sprites/enemy/gibs/gib_0.png"), preload("res://assets/sprites/enemy/gibs/gib_1.png"),
	preload("res://assets/sprites/enemy/gibs/gib_2.png"), preload("res://assets/sprites/enemy/gibs/gib_3.png"),
	preload("res://assets/sprites/enemy/gibs/gib_4.png"),
]
const MAX_STAINS := 150  ## oldest stains vanish first


## A small burst of blood thrown away from `from`. Called on every hit, so it stays cheap.
static func splash(holder: Node, pos: Vector2, from: Vector2, amount: float) -> void:
	var away := (pos - from).normalized()
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(6 + int(amount) * 2, 6, 24)
	p.lifetime = 0.45
	p.direction = away + Vector2(0, -0.4)
	p.spread = 50.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.gravity = Vector2(0, 260.0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.1, 0.14))
	grad.set_color(1, Color(0.35, 0.03, 0.06))
	p.color_ramp = grad
	p.z_index = 20
	holder.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Death: a big burst, floor stains and a few bones / organs thrown in an arc.
static func death(holder: Node, pos: Vector2, from: Vector2) -> void:
	splash(holder, pos, from, 8.0)
	var floor_pos := pos + Vector2(0, 20)  # `pos` is torso height; stains belong on the floor
	for i in 2:
		stain(holder, floor_pos + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 16.0))
	var away := (pos - from).normalized()
	for i in randi_range(4, 7):
		var g := Sprite2D.new()
		g.texture = GIBS[randi() % GIBS.size()]
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.add_to_group("gibs")
		g.z_index = 21
		holder.add_child(g)
		g.global_position = pos
		var dir := (away * 0.7 + Vector2.from_angle(randf() * TAU)).normalized()
		var land := pos + Vector2(0, 14) + dir * randf_range(14.0, 56.0)
		var peak := randf_range(16.0, 40.0)
		var flight := randf_range(0.3, 0.5)
		var tw := g.create_tween()  # bound to the gib, so it keeps going after the enemy is freed
		tw.tween_method(func(k: float): g.global_position = pos.lerp(land, k) + Vector2(0, -sin(k * PI) * peak), 0.0, 1.0, flight)
		tw.parallel().tween_property(g, "rotation", randf_range(-6.0, 6.0), flight)
		tw.tween_callback(func(): g.z_index = -40)  # on the floor now: above the stains, under the actors
		tw.tween_interval(randf_range(4.0, 8.0))
		tw.tween_property(g, "modulate:a", 0.0, 1.0)
		tw.tween_callback(g.queue_free)


## Wipes the arena's blood: the stains and the gibs on the floor fade out, and the floor stops reflecting like a pool.
## The blood painted in the background and the water puddles stay.
static func clear(tree: SceneTree, fade := 1.0) -> void:
	var decals := tree.get_first_node_in_group("decals")
	if decals:
		for d in decals.get_children():
			_fade_out(d, fade)
	for g in tree.get_nodes_in_group("gibs"):
		_fade_out(g, fade)
	var map := tree.get_first_node_in_group("reflection_map") as ReflectionMap
	if map:
		tree.create_timer(fade).timeout.connect(map.reset_wet)


static func _fade_out(item: CanvasItem, time: float) -> void:
	var tw := item.create_tween()  # bound to the item; a gib's own fade only starts seconds later, after this one has freed it
	tw.tween_property(item, "modulate:a", 0.0, time)
	tw.tween_callback(item.queue_free)


static func stain(holder: Node, pos: Vector2) -> void:
	var decals := holder.get_tree().get_first_node_in_group("decals")
	if decals == null:
		return
	if decals.get_child_count() >= MAX_STAINS:
		decals.get_child(0).queue_free()
	var d := Sprite2D.new()
	d.texture = STAINS[randi() % STAINS.size()]
	d.scale = Vector2.ONE * randf_range(0.22, 0.4)
	d.modulate.a = 0.9
	decals.add_child(d)
	d.global_position = pos
	var map := holder.get_tree().get_first_node_in_group("reflection_map")
	if map:  # fresh blood is a puddle too: zombies reflect in it
		map.stamp_wet(pos, d.texture.get_width() * d.scale.x * 0.3)
