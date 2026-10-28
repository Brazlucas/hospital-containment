class_name DamageNumber
extends RefCounted
## The small number that pops above an enemy when it is hit, rises a little and fades.

const UNSHADED: Material = preload("res://resources/materials/unshaded.tres")
const MAX_ALIVE := 80  ## numbers on screen at once (shotguns and SMGs would flood it)
const NORMAL := Color(1.0, 1.0, 1.0)
const CRIT := Color(1.0, 0.8, 0.25)
const BOX := Vector2(40, 12)


static func popup(parent: Node, at: Vector2, amount: float, crit := false) -> void:
	if parent.get_tree().get_nodes_in_group("damage_numbers").size() >= MAX_ALIVE:
		return
	var l := Label.new()
	l.add_to_group("damage_numbers")
	l.text = Stats.number(amount)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = BOX
	l.pivot_offset = BOX * 0.5
	l.z_index = 30
	l.material = UNSHADED  # readable in a blackout too
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 10 if crit else 8)
	l.add_theme_color_override("font_color", CRIT if crit else NORMAL)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	parent.add_child(l)
	l.global_position = at + Vector2(randf_range(-7.0, 7.0), randf_range(-3.0, 3.0)) - BOX * 0.5
	l.scale = Vector2.ONE * 1.4
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_property(l, "position:y", l.position.y - 16.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tw.finished.connect(l.queue_free)
